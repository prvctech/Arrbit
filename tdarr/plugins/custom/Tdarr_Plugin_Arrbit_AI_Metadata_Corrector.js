const details = () => ({
  id: "Tdarr_Plugin_CGEDIT_AI_Metadata_Corrector",
  Stage: "Pre-processing",
  Name: "CGEDIT AI Metadata Corrector",
  Type: "Audio",
  Operation: "Transcode",
  Description:
    "Reads a <file>.ai_lang.json produced by the AI Language Detection plugin and, when mismatches between detected and tagged languages are found, updates the MKV audio track language metadata using ffmpeg.",
  Version: "0.1",
  Tags: "pre-processing,ai,metadata,ffmpeg",
  Inputs: [
    {
      name: "results_dir",
      type: "string",
      defaultValue: "/app/arrbit/data/temp",
      inputUI: { type: "text" },
      tooltip: "Directory where ai_language_detection writes its JSON results.",
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
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: "",
  };

  try {
    if (file.fileMedium !== "video") {
      response.infoLog +=
        "☒ File is not a video, skipping AI metadata correction.\n";
      return response;
    }

    const tempDir = inputs.results_dir || "/app/arrbit/data/temp";
    const fileBasename =
      path.parse(file.fileName || file.name || file.file).name ||
      path.parse(file.file).name;
    const resultsPath = `${tempDir}/${fileBasename}.ai_lang.json`;

    if (!fs.existsSync(resultsPath)) {
      response.infoLog += `☒ AI results not found for this file: ${resultsPath}\n`;
      return response;
    }

    let parsed = null;
    try {
      parsed = JSON.parse(fs.readFileSync(resultsPath, "utf8"));
    } catch (e) {
      response.infoLog += `☒ Failed to parse AI results JSON: ${e}\n`;
      return response;
    }

    const results = parsed.results || {};
    const streams = file.ffProbeData.streams || [];

    // Build ffmpeg metadata edits based on mismatches
    let ffmpegMetaEdits = "";
    let audioStreamOutputIndex = 0;
    let convertNeeded = false;

    streams.forEach((stream) => {
      if (stream.codec_type && stream.codec_type.toLowerCase() === "audio") {
        const idx = stream.index; // input stream index
        const ai = results[idx];
        const detected = ai && ai.language ? ai.language : null;
        const currentLangTag =
          stream.tags &&
          (stream.tags.language || stream.tags.LANGUAGE || stream.tags.lang)
            ? stream.tags.language || stream.tags.LANGUAGE || stream.tags.lang
            : null;

        if (
          detected &&
          currentLangTag &&
          detected.toLowerCase().startsWith(currentLangTag.toLowerCase())
        ) {
          response.infoLog += `☑ Audio stream ${idx} language matches detected (${detected}).\n`;
        } else if (
          detected &&
          (!currentLangTag ||
            detected.toLowerCase() !== (currentLangTag || "").toLowerCase())
        ) {
          // We need to set metadata language for this output stream
          response.infoLog += `☒ Audio stream ${idx} metadata mismatch: current='${currentLangTag}' detected='${detected}' — scheduling metadata update.\n`;
          // ffmpeg expects metadata:s:a:<streamIndex> language=<code>
          ffmpegMetaEdits += ` -metadata:s:a:${audioStreamOutputIndex} language=${detected}`;
          convertNeeded = true;
        } else {
          response.infoLog += `⚠ Could not determine detected language for stream ${idx}.\n`;
        }

        audioStreamOutputIndex += 1;
      }
    });

    if (convertNeeded) {
      // Build a copy command preserving streams but changing metadata
      // Map all input streams
      let mapCmd = " -map 0";
      const ffmpegPreset = `${ffmpegMetaEdits} -c copy -map 0 -max_muxing_queue_size 9999`;
      response.preset = `, ${ffmpegPreset}`;
      response.reQueueAfter = true;
      response.processFile = true;
      response.infoLog += `☑ Scheduled ffmpeg metadata rewrite: ${ffmpegMetaEdits}\n`;
    } else {
      response.infoLog +=
        "☑ No metadata changes required based on AI results.\n";
    }

    return response;
  } catch (err) {
    response.infoLog += `☒ Unexpected error in AI metadata corrector plugin: ${err}\n`;
    return response;
  }
};

module.exports.details = details;
module.exports.plugin = plugin;
