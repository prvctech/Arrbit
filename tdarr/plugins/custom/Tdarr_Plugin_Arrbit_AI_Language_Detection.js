const details = () => ({
  id: "Tdarr_Plugin_Arrbit_AI_Language_Detection",
  Stage: "Pre-processing",
  Name: "Arrbit - AI Language Detection (WhisperX)",
  Type: "Audio",
  Operation: "Transcode",
  Description:
    "Samples a 15s snippet (default at minute 3) from each audio track and runs WhisperX to determine the spoken language. Writes a small JSON result into /app/arrbit/data/temp/ named <file_basename>.ai_lang.json.",
  Version: "0.3",
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
      defaultValue: "base",
      inputUI: { type: "text", placeholder: "base", allowCustom: true },
      tooltip:
        "WhisperX model size (base default for better multilingual accuracy vs tiny).",
    },
    {
      name: "compute_type",
      type: "string",
      defaultValue: "float32",
      inputUI: { type: "text", placeholder: "float32", allowCustom: true },
      tooltip:
        "faster-whisper/ctranslate2 compute type (float32, int8, int8_float16, etc.). Use float32 for widest CPU compatibility.",
    },
    {
      name: "suppress_warnings",
      type: "boolean",
      defaultValue: true,
      inputUI: { type: "checkbox" },
      tooltip:
        "Set PYTHONWARNINGS=ignore to hide noisy torchaudio deprecation warnings.",
    },
    {
      name: "config_path",
      type: "string",
      defaultValue: "/app/arrbit/tdarr/config/whisperx.conf",
      inputUI: {
        type: "text",
        placeholder: "/app/arrbit/tdarr/config/whisperx.conf",
        allowCustom: true,
      },
      tooltip:
        "Path to whisperx.conf; if present its settings override the inputs (model, compute_type, language, device, output_dir).",
    },
    {
      name: "enable_cjk_script_inference",
      type: "boolean",
      defaultValue: true,
      inputUI: { type: "checkbox" },
      tooltip:
        "If true (default), apply a lightweight script-based heuristic to distinguish Japanese vs Korean vs Chinese when WhisperX returns a non-CJK language. Disable to rely strictly on WhisperX output.",
    },
    {
      name: "logs",
      type: "boolean",
      defaultValue: false,
      inputUI: { type: "checkbox" },
      tooltip:
        "If true, retain WhisperX stdout/stderr diagnostics in results JSON. If false (default), redact them for smaller JSON output.",
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
    let model = inputs.model || "base";
    let computeType = inputs.compute_type || "float32";
    let suppressWarnings = inputs.suppress_warnings !== false; // default true
    let languagePref = null; // from config (not passed currently to CLI; could add --language)
    let devicePref = "cpu";
    let outputDirOverride = null;

    // Load config if available
    const cfgPath =
      inputs.config_path || "/app/arrbit/tdarr/config/whisperx.conf";
    try {
      if (fs.existsSync(cfgPath)) {
        const cfgRaw = fs.readFileSync(cfgPath, "utf8");
        cfgRaw.split(/\r?\n/).forEach((line) => {
          const trimmed = line.trim();
          if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("="))
            return;
          const [kRaw, vRaw] = trimmed.split("=", 2);
          const k = kRaw.trim().toUpperCase();
          const v = (vRaw || "").trim();
          switch (k) {
            case "WHISPERX_MODEL":
              if (v) model = v;
              break;
            case "WHISPERX_COMPUTE_TYPE":
              if (v) computeType = v;
              break;
            case "WHISPERX_LANGUAGE":
              if (v && v.toLowerCase() !== "auto") languagePref = v;
              break;
            case "WHISPERX_DEVICE":
              if (v) devicePref = v;
              break;
            case "WHISPERX_OUTPUT_DIR":
              if (v) outputDirOverride = v;
              break;
            case "WHISPERX_SUPPRESS_WARNINGS":
              if (v) suppressWarnings = v.toLowerCase() === "true";
              break;
            default:
              break;
          }
        });
      }
    } catch (e) {
      response.infoLog += `⚠ Failed to read whisperx config: ${e}\n`;
    }
    const sampleStartMinute = Number(inputs.sample_start_minute) || 3;
    const sampleLength = Number(inputs.sample_length_seconds) || 15;
    const cleanupIntermediate =
      inputs.cleanup_intermediate === false ? false : true;
    const maxTranscodeSeconds = Number(inputs.max_transcode_seconds) || 120;
    const maxFileSizeBytes = Number(inputs.max_file_size_bytes) || 250000000;

    response.infoLog += `ℹ WhisperX settings -> model=${model}, compute_type=${computeType}, device=${devicePref}, heuristic_CJK=${
      inputs.enable_cjk_script_inference !== false ? "on" : "off"
    }, logs=${
      inputs.logs ? "on" : "off"
    } (broad multilingual detection enabled)\n`;

    // Canonicalize source path: some Tdarr runs provide `file.file` instead of `file.path`.
    const sourcePath = file.path || file.file || file.fileName || file.name;
    if (!sourcePath) {
      response.infoLog +=
        "☒ Source path unavailable on file object (file.path/file.file missing). Skipping.\n";
      return response;
    }

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
        if (fs.existsSync(sourcePath)) {
          sourceSize = fs.statSync(sourcePath).size || 0;
          skipHeavyTranscode = sourceSize > maxFileSizeBytes;
        }
      } catch (e) {}
      // Build a safe output filename
      const outFile = `${tempDir}/${fileBasename}_track${idx}_sample.wav`;

      // Extract 15s sample for this specific audio stream
      // Use ffmpeg to mix down/convert into a clean WAV suitable for WhisperX
      const ffmpegCmd = `ffmpeg -y -i "${sourcePath}" -ss ${startSeconds} -t ${sampleLength} -map 0:${stream.index} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${outFile}"`;

      try {
        response.infoLog += `☑ Extracting sample for audio stream ${idx} -> ${outFile}\n`;
        child.execSync(ffmpegCmd, {
          stdio: "inherit",
          timeout: maxTranscodeSeconds * 1000,
        });
      } catch (err) {
        // If extraction by input stream index fails, try mapping by audio stream order (0:a:<order>)
        try {
          const ffmpegFallbackByOrder = `ffmpeg -y -i "${sourcePath}" -ss ${startSeconds} -t ${sampleLength} -map 0:a:${idx} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${outFile}"`;
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
            const convCmd = `ffmpeg -y -i "${sourcePath}" -map 0:a:${idx} -vn -ac 1 -ar 16000 -c:a libopus -b:a 64000 "${convFile}"`;
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
        const whisperArgs = [
          outFile,
          "--model",
          model,
          "--device",
          devicePref || "cpu",
          "--compute_type",
          computeType,
          "--output_dir",
          outputDirOverride || whisperOutDir,
          "--output_format",
          "json",
          "--task",
          "transcribe",
          "--print_progress",
          "False",
        ];
        if (languagePref) {
          whisperArgs.push("--language", languagePref);
        }

        response.infoLog += `☑ Running whisperx for track ${idx} (capturing output)\n`;

        // Use spawnSync to capture stdout/stderr and avoid shell injection
        const env = Object.assign({}, process.env);
        if (suppressWarnings) env.PYTHONWARNINGS = "ignore";
        const spawnResult = child.spawnSync(whisperxPath, whisperArgs, {
          encoding: "utf8",
          timeout: Math.max(180000, maxTranscodeSeconds * 1000 * 2),
          env,
        });

        // Record diagnostics into results so user can see failures
        const keepLogs = inputs.logs === true;
        const diag = {
          status: spawnResult.status,
          signal: spawnResult.signal,
          stdout:
            keepLogs && spawnResult.stdout
              ? String(spawnResult.stdout).slice(0, 2000)
              : keepLogs
              ? ""
              : undefined,
          stderr:
            keepLogs && spawnResult.stderr
              ? String(spawnResult.stderr).slice(0, 2000)
              : keepLogs
              ? ""
              : undefined,
        };

        // If whisperx failed due to requested float16 compute type not supported,
        // retry once with compute_type float32 (slower but more compatible).
        let retryDiag = null;
        if ((diag.stderr || "").includes("Requested float16 compute type")) {
          response.infoLog += `⚠ Detected float16 compute-type error; retrying WhisperX with compute_type=float32 for track ${idx}\n`;
          try {
            const retryArgs = whisperArgs.concat(["--compute_type", "float32"]);
            const retryResult = child.spawnSync(whisperxPath, retryArgs, {
              encoding: "utf8",
              timeout: Math.max(180000, maxTranscodeSeconds * 1000 * 2),
            });
            retryDiag = {
              status: retryResult.status,
              signal: retryResult.signal,
              stdout:
                keepLogs && retryResult.stdout
                  ? String(retryResult.stdout).slice(0, 2000)
                  : keepLogs
                  ? ""
                  : undefined,
              stderr:
                keepLogs && retryResult.stderr
                  ? String(retryResult.stderr).slice(0, 2000)
                  : keepLogs
                  ? ""
                  : undefined,
            };
          } catch (e) {
            retryDiag = { error: String(e) };
          }
        }

        // WhisperX will create a JSON file with the same basename
        const generatedJson = `${whisperOutDir}/${
          path.parse(outFile).name
        }.json`;
        let detected = "und";

        if (fs.existsSync(generatedJson)) {
          try {
            const j = JSON.parse(fs.readFileSync(generatedJson, "utf8"));
            if (j.language) detected = j.language;
            else if (j?.segments && j.segments[0] && j.segments[0].language)
              detected = j.segments[0].language;
            else if (j?.detected_language) detected = j.detected_language;

            // Heuristic 1: parse stdout line 'Detected language: xx'
            const stdout = (
              (diag.stdout || "") +
              "\n" +
              (diag.stderr || "")
            ).trim();
            const langLineMatch = stdout.match(
              /Detected language:\s*([a-z]{2,3})/i
            );
            if (langLineMatch) {
              const cliLang = langLineMatch[1].toLowerCase();
              if (cliLang && cliLang !== detected) {
                response.infoLog += `⚠ Overriding JSON language '${detected}' with CLI-detected '${cliLang}' (heuristic) for track ${idx}\n`;
                detected = cliLang;
              }
            }

            // Heuristic 2 (refined, optional): Script-based disambiguation for CJK languages only if original detection wasn't one of them
            // We attempt to infer: presence of Kana => Japanese, Hangul => Korean, otherwise Han-only => Chinese.
            if (
              inputs.enable_cjk_script_inference !== false &&
              ["ja", "zh", "ko"].indexOf(detected) === -1
            ) {
              try {
                const sampleText =
                  j.segments && j.segments[0] && j.segments[0].text
                    ? j.segments
                        .map((s) => s.text)
                        .join(" ")
                        .slice(0, 800)
                    : "";
                if (sampleText) {
                  const hiragana = sampleText.match(/[\u3040-\u309F]/g) || [];
                  const katakana =
                    sampleText.match(/[\u30A0-\u30FF\uFF66-\uFF9F]/g) || [];
                  const hangul =
                    sampleText.match(
                      /[\uAC00-\uD7AF\u1100-\u11FF\u3130-\u318F]/g
                    ) || [];
                  const han = sampleText.match(/[\u4E00-\u9FFF]/g) || [];
                  const kanaCount = hiragana.length + katakana.length;
                  const hangulCount = hangul.length;
                  const hanCount = han.length;
                  const textLen = Math.max(sampleText.length, 1);
                  const kanaRatio = kanaCount / textLen;
                  const hangulRatio = hangulCount / textLen;
                  const hanRatio = hanCount / textLen;
                  // Thresholds chosen conservatively to avoid false overrides
                  const MIN_ABS = 6; // minimum absolute script chars
                  const MIN_RATIO = 0.04; // minimum ratio of those chars to text length
                  let inferred = null;
                  if (kanaCount >= MIN_ABS && kanaRatio >= MIN_RATIO) {
                    inferred = "ja";
                  } else if (
                    hangulCount >= MIN_ABS &&
                    hangulRatio >= MIN_RATIO
                  ) {
                    inferred = "ko";
                  } else if (
                    hanCount >= MIN_ABS + 4 &&
                    hanRatio >= MIN_RATIO + 0.01
                  ) {
                    // require slightly more confidence for Chinese vs Japanese Kanji overlap
                    inferred = "zh";
                  }
                  if (inferred && inferred !== detected) {
                    response.infoLog += `⚠ Heuristic CJK script inference override: '${detected}' -> '${inferred}' for track ${idx} (kana=${kanaCount}/${kanaRatio.toFixed(
                      2
                    )}, hangul=${hangulCount}/${hangulRatio.toFixed(
                      2
                    )}, han=${hanCount}/${hanRatio.toFixed(2)})\n`;
                    detected = inferred;
                  }
                }
              } catch (e) {
                /* ignore heuristic errors */
              }
            }

            results[idx] = {
              file: outFile,
              json: generatedJson,
              language: detected,
              whisper_diag: diag,
              whisper_retry_diag: retryDiag,
            };

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
            results[idx] = {
              file: outFile,
              error: "json_parse_failed",
              whisper_diag: diag,
              whisper_retry_diag: retryDiag,
            };
          }
        } else {
          response.infoLog += `⚠ Expected whisperx output not found: ${generatedJson}\n`;
          results[idx] = {
            file: outFile,
            error: "whisper_output_missing",
            language: null,
            whisper_diag: diag,
            whisper_retry_diag: retryDiag,
          };
        }
      } catch (errWh) {
        response.infoLog += `☒ whisperx failed for stream ${idx}: ${errWh}\n`;
        results[idx] = {
          error: "whisper_failed",
          whisper_diag: { message: String(errWh) },
        };
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
