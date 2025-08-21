const details = () => ({
  id: "Tdarr_Plugin_Arrbit_AI_Language_Detection",
  Stage: "Pre-processing",
  Name: "Arrbit - AI Language Detection (WhisperX)",
  Type: "Audio",
  Operation: "Transcode",
  Description:
    "Samples a 15s snippet (default at minute 3) from each audio track and runs WhisperX to determine the spoken language. Writes a small JSON result into /app/arrbit/data/temp/ named <file_basename>.ai_lang.json.",
  Version: "0.1",
  Tags: "pre-processing,ai,whisperx,language-detection",
  Inputs: [
    {
      name: "sample_start_minute",
      type: "number",
      defaultValue: 3,
      inputUI: { type: "number", placeholder: "3", allowCustom: true },
      tooltip:
        "Minute to start sampling from (default 3). If file is shorter the start will be reduced.",
    },
    {
      name: "cleanup_intermediate",
      type: "boolean",
      defaultValue: true,
      inputUI: { type: "checkbox" },
      tooltip:
        "Remove intermediate .opus and .wav samples after successful processing (default true).",
    },
    {
      name: "max_transcode_seconds",
      type: "number",
      defaultValue: 120,
      inputUI: { type: "number", placeholder: "120", allowCustom: true },
      tooltip:
        "Maximum seconds allowed for any single transcode/extraction command (default 120).",
    },
    {
      name: "max_file_size_bytes",
      type: "number",
      defaultValue: 250000000,
      inputUI: { type: "number", placeholder: "250000000", allowCustom: true },
      tooltip:
        "Maximum size of the source media file to attempt heavy transcodes on; if larger, skip transcode and record as skipped (default 250MB).",
    },
    {
      name: "sample_length_seconds",
      type: "number",
      defaultValue: 15,
      inputUI: { type: "number", placeholder: "15", allowCustom: true },
      tooltip: "Length in seconds of the sample to analyze (default 15).",
    },
    {
      name: "whisperx_path",
      type: "string",
      defaultValue: "/app/arrbit/environments/whisperx-env/bin/whisperx",
      inputUI: {
        type: "text",
        placeholder: "/app/arrbit/environments/whisperx-env/bin/whisperx",
        allowCustom: true,
      },
      tooltip: "Path to whisperx executable inside the container.",
    },
    {
      name: "model",
      type: "string",
      defaultValue: "tiny",
      inputUI: { type: "text", placeholder: "tiny", allowCustom: true },
      tooltip:
        "WhisperX model to use (tiny, base, small, etc.). Smaller models are faster.",
    },
  ],
});

const plugin = (file, librarySettings, inputs, otherArguments) => {
  const path = require("path");
  const fs = require("fs");
  const child = require("child_process");
  const lib = require("../methods/lib")();

  inputs = lib.loadDefaultValues(inputs, details);

  const response = {
    processFile: false,
    preset: "",
    container: `.${file.container}`,
    handBrakeMode: false,
    FFmpegMode: false,
    reQueueAfter: false,
    infoLog: "",
  };

  try {
  if (file.fileMedium !== "video") {
      response.infoLog +=
        "☒ File is not a video, skipping AI language detection.\n";
      return response;
    }

    const streams = file.ffProbeData.streams || [];
    const audioStreams = streams.filter(
      (s) => s.codec_type && s.codec_type.toLowerCase() === "audio"
    );

    // NOTE: This plugin intentionally ignores existing stream title metadata, channel-layout
    // descriptions (e.g., "English 5.1 Surround"), and any user-supplied language tags.
    // Its sole responsibility is to infer the spoken language from the raw audio content.
    // Downstream, the Metadata Corrector plugin treats this detection output as the
    // authoritative truth for the language flag; we do not try to reconcile or parse
    // title strings here.

    if (audioStreams.length === 0) {
      response.infoLog += "☒ No audio streams found.\n";
      return response;
    }

    const tempDir = "/app/arrbit/data/temp";
    try {
      fs.mkdirSync(tempDir, { recursive: true });
    } catch (e) {}

    const fileBasename =
      path.parse(file.fileName || file.name || file.file).name ||
      path.parse(file.file).name;

    const whisperxPath =
      inputs.whisperx_path ||
      "/app/arrbit/environments/whisperx-env/bin/whisperx";
    const model = inputs.model || "tiny";
    const sampleStartMinute = Number(inputs.sample_start_minute) || 3;
    const sampleLength = Number(inputs.sample_length_seconds) || 15;
    const cleanupIntermediate =
      inputs.cleanup_intermediate === false ? false : true;
    const maxTranscodeSeconds = Number(inputs.max_transcode_seconds) || 120;
    const maxFileSizeBytes = Number(inputs.max_file_size_bytes) || 250000000;

    // compute startSeconds respecting duration if available
    const duration = Number(file.ffProbeData?.format?.duration) || 0;
    let startSeconds = sampleStartMinute * 60;
    if (duration && startSeconds + sampleLength > duration) {
      startSeconds = Math.max(0, Math.floor(duration - sampleLength));
    }

    const results = {};

  audioStreams.forEach((stream, idx) => {
      // Prepare variables for this iteration
      let convFile = null;
      let sourceSize = 0;
      let skipHeavyTranscode = false;
      try {
        if (fs.existsSync(file.path)) {
          sourceSize = fs.statSync(file.path).size || 0;
          skipHeavyTranscode = sourceSize > maxFileSizeBytes;
        }
      } catch (e) {}
      // Build a safe output filename
      const outFile = `${tempDir}/${fileBasename}_track${idx}_sample.wav`;

      // Extract 15s sample for this specific audio stream
      // Use ffmpeg to mix down/convert into a clean WAV suitable for WhisperX
      const ffmpegCmd = `ffmpeg -y -i "${file.path}" -ss ${startSeconds} -t ${sampleLength} -map 0:${stream.index} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${outFile}"`;

  try {
        response.infoLog += `☑ Extracting sample for audio stream ${idx} -> ${outFile}\n`;
        child.execSync(ffmpegCmd, {
          stdio: "inherit",
          timeout: maxTranscodeSeconds * 1000,
        });
      } catch (err) {
        // If extraction by input stream index fails, try mapping by audio stream order (0:a:<order>)
        try {
          const ffmpegFallbackByOrder = `ffmpeg -y -i "${file.path}" -ss ${startSeconds} -t ${sampleLength} -map 0:a:${idx} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${outFile}"`;
          response.infoLog += `⚠ ffmpeg by index failed, trying map by audio order for stream ${idx}\n`;
          child.execSync(ffmpegFallbackByOrder, {
            stdio: "inherit",
            timeout: maxTranscodeSeconds * 1000,
          });
        } catch (err2) {
          // As a last resort transcode the specific audio stream into an intermediate (opus) file and sample from it
          try {
            if (skipHeavyTranscode) {
              response.infoLog += `⚠ Source file too large (${sourceSize}) - skipping heavy transcode for stream ${idx}\n`;
              results[idx] = { error: "source_too_large" };
              return;
            }

            convFile = `${tempDir}/${fileBasename}_track${idx}_conv.opus`;
            const convCmd = `ffmpeg -y -i "${file.path}" -map 0:a:${idx} -vn -ac 1 -ar 16000 -c:a libopus -b:a 64000 "${convFile}"`;
            response.infoLog += `⚠ ffmpeg map-by-order failed, transcoding audio stream ${idx} to intermediate ${convFile}\n`;
            child.execSync(convCmd, {
              stdio: "inherit",
              timeout: maxTranscodeSeconds * 1000,
            });

            // Now extract the sample from the intermediate file (map 0:0)
            const ffmpegFromConv = `ffmpeg -y -i "${convFile}" -ss ${startSeconds} -t ${sampleLength} -map 0:0 -vn -ac 1 -ar 16000 -c:a pcm_s16le "${outFile}"`;
            response.infoLog += `☑ Extracting sample from intermediate for stream ${idx} -> ${outFile}\n`;
            child.execSync(ffmpegFromConv, {
              stdio: "inherit",
              timeout: maxTranscodeSeconds * 1000,
            });
          } catch (err3) {
            response.infoLog += `☒ Failed to extract sample for stream ${idx}: ${err3}\n`;
            results[idx] = { error: "extract_failed" };
            return;
          }
        }
      }

      // Run whisperx CLI to produce JSON output into tempDir
  try {
        const whisperOutDir = tempDir;
        const whisperCmd = `${whisperxPath} "${outFile}" --model ${model} --device cpu --output_dir "${whisperOutDir}" --output_format json --task transcribe --print_progress False`;
        response.infoLog += `☑ Running whisperx for track ${idx}\n`;
        // allow slightly more time for whisper runs than transcodes
        child.execSync(whisperCmd, {
          stdio: "inherit",
          timeout: Math.max(180000, maxTranscodeSeconds * 1000 * 2),
        });

        // WhisperX will create a JSON file with the same basename
        const generatedJson = `${whisperOutDir}/${
          path.parse(outFile).name
        }.json`;
        let detected = "und";
        if (fs.existsSync(generatedJson)) {
          try {
            const j = JSON.parse(fs.readFileSync(generatedJson, "utf8"));
            // Try common places for detected language
            if (j.language) detected = j.language;
            else if (j?.segments && j.segments[0] && j.segments[0].language)
              detected = j.segments[0].language;
            else if (j?.detected_language) detected = j.detected_language;
            results[idx] = {
              file: outFile,
              json: generatedJson,
              language: detected,
            };
            response.infoLog += `☑ Detected (audio content only) language for stream ${idx}: ${detected}\n`;
            // cleanup intermediates (wav/opus) if requested, but keep whisper JSON
            if (cleanupIntermediate) {
              try {
                if (convFile && fs.existsSync(convFile))
                  fs.unlinkSync(convFile);
              } catch (e) {}
              try {
                if (fs.existsSync(outFile)) fs.unlinkSync(outFile);
              } catch (e) {}
            }
          } catch (errJson) {
            response.infoLog += `⚠ Failed to parse whisperx JSON for track ${idx}: ${errJson}\n`;
            results[idx] = { file: outFile, error: "json_parse_failed" };
          }
        } else {
          response.infoLog += `⚠ Expected whisperx output not found: ${generatedJson}\n`;
          results[idx] = { file: outFile, error: "whisper_output_missing" };
        }
      } catch (errWh) {
        response.infoLog += `☒ whisperx failed for stream ${idx}: ${errWh}\n`;
        results[idx] = { error: "whisper_failed" };
      }
    });

    // Write a concise results file
    const resultsPath = `${tempDir}/${fileBasename}.ai_lang.json`;
    try {
      fs.writeFileSync(
        resultsPath,
        JSON.stringify({ file: file.file, results: results }, null, 2)
      );
      response.infoLog += `☑ Written detection results to ${resultsPath}\n`;
    } catch (e) {
      response.infoLog += `☒ Failed to write results JSON: ${e}\n`;
    }

    // We don't modify the media in this plugin; it only produces results for the corrector
    response.infoLog +=
      "✔ AI language detection completed (results available for ai_metadata_corrector).\n";
    return response;
  } catch (err) {
    response.infoLog += `☒ Unexpected error in AI language detection plugin: ${err}\n`;
    return response;
  }
};

module.exports.details = details;
module.exports.plugin = plugin;
