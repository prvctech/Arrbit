const details = () => ({
  id: "Tdarr_Plugin_CGEDIT_AI_Language_Detection",
  Stage: "Pre-processing",
  Name: "CGEDIT AI Language Detection (WhisperX)",
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
      inputUI: { type: "number" },
      tooltip:
        "Minute to start sampling from (default 3). If file is shorter the start will be reduced.",
    },
    {
      name: "sample_length_seconds",
      type: "number",
      defaultValue: 15,
      inputUI: { type: "number" },
      tooltip: "Length in seconds of the sample to analyze (default 15).",
    },
    {
      name: "whisperx_path",
      type: "string",
      defaultValue: "/app/arrbit/environments/whisperx-env/bin/whisperx",
      inputUI: { type: "text" },
      tooltip: "Path to whisperx executable inside the container.",
    },
    {
      name: "model",
      type: "string",
      defaultValue: "tiny",
      inputUI: { type: "text" },
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

    // Determine start position safely
    const format = file.ffProbeData.format || {};
    const duration = Number(format.duration) || 0;
    let startSeconds = sampleStartMinute * 60;
    if (duration > 0 && startSeconds + sampleLength > duration) {
      // Shift start to a safe position
      if (duration > sampleLength + 5) {
        startSeconds = Math.max(5, Math.floor(duration / 3));
      } else {
        startSeconds = Math.max(
          0,
          Math.floor(Math.max(0, duration - sampleLength - 1))
        );
      }
    }

    const results = {};

    audioStreams.forEach((stream, idx) => {
      // Build a safe output filename
      const outFile = `${tempDir}/${fileBasename}_track${idx}_sample.wav`;

      // Extract 15s sample for this specific audio stream
      // Use ffmpeg to mix down/convert into a clean WAV suitable for WhisperX
      const ffmpegCmd = `ffmpeg -y -i "${file.path}" -ss ${startSeconds} -t ${sampleLength} -map 0:${stream.index} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${outFile}"`;

      try {
        response.infoLog += `☑ Extracting sample for audio stream ${idx} -> ${outFile}\n`;
        child.execSync(ffmpegCmd, { stdio: "inherit", timeout: 120000 });
      } catch (err) {
        // If extraction fails try a fallback that maps by stream order instead of index
        try {
          const ffmpegFallback = `ffmpeg -y -i "${file.path}" -ss ${startSeconds} -t ${sampleLength} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${outFile}"`;
          response.infoLog += `⚠ ffmpeg by index failed, running fallback for stream ${idx}\n`;
          child.execSync(ffmpegFallback, { stdio: "inherit", timeout: 120000 });
        } catch (err2) {
          response.infoLog += `☒ Failed to extract sample for stream ${idx}: ${err2}\n`;
          results[idx] = { error: "extract_failed" };
          return;
        }
      }

      // Run whisperx CLI to produce JSON output into tempDir
      try {
        const whisperOutDir = tempDir;
        const whisperCmd = `${whisperxPath} "${outFile}" --model ${model} --device cpu --output_dir "${whisperOutDir}" --output_format json --task transcribe --print_progress False`;
        response.infoLog += `☑ Running whisperx for track ${idx}\n`;
        child.execSync(whisperCmd, { stdio: "inherit", timeout: 180000 });

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
