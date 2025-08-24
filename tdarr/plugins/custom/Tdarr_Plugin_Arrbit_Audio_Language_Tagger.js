// Tdarr plugin: Arrbit Audio Language Tagger
// Invokes tdarr/plugins/custom/detect_language.py to detect per-audio-track language
// and updates MKV track language tags via mkvpropedit (no transcoding).

module.exports.details = function details() {
  return {
    id: "Tdarr_Plugin_Arrbit_Audio_Language_Tagger",
    Stage: "Pre-processing",
    Name: "Arrbit Audio Language Tagger",
    Type: "Audio",
    Operation: "Metadata",
    Description:
      "Detect audio language using WhisperX and tag MKV tracks via mkvpropedit (no transcoding)",
    Version: "1.0",
    Tags: "pre-processing,audio,metadata",
    Inputs: [
      {
        name: "confidence_threshold",
        type: "number",
        defaultValue: 85,
        inputUI: { type: "text" },
        tooltip: "Minimum confidence %",
      },
      {
        name: "sample_duration",
        type: "number",
        defaultValue: 60,
        inputUI: { type: "text" },
        tooltip: "Seconds of audio to sample (max 60)",
      },
      {
        name: "dry_run",
        type: "boolean",
        defaultValue: false,
        inputUI: { type: "dropdown", options: ["false", "true"] },
        tooltip: "If true, do not modify files",
      },
      {
        name: "backup_original",
        type: "boolean",
        defaultValue: true,
        inputUI: { type: "dropdown", options: ["true", "false"] },
        tooltip: "Backup original language tags",
      },
    ],
  };
};

module.exports.plugin = function plugin(
  file,
  librarySettings,
  inputs,
  otherArguments
) {
  const path = require("path");
  const { execSync } = require("child_process");
  const fs = require("fs");

  const response = {
    processFile: false,
    preset: "",
    container: ".mkv",
    handBrakeMode: false,
    FFmpegMode: false,
    reQueueAfter: false,
    infoLog: "",
    error: false,
  };

  try {
    if (!file || !file.container || file.container.toLowerCase() !== "mkv") {
      response.infoLog += "⚠️ Not an MKV file - skipping\n";
      return response;
    }

    const scriptPath = path.join(__dirname, "detect_language.py");
    if (!fs.existsSync(scriptPath)) {
      response.error = true;
      response.infoLog += `❌ Missing detection script: ${scriptPath}\n`;
      return response;
    }

    const sampleDuration = inputs.sample_duration || 60;
    const confidence = inputs.confidence_threshold || 85;
    const dryRun =
      ("" + inputs.dry_run).toLowerCase() === "true" || inputs.dry_run === true;
    const backup =
      ("" + inputs.backup_original).toLowerCase() === "true" ||
      inputs.backup_original === true;

    // Build command and quote paths with spaces
    const cmd = [
      "python3",
      scriptPath,
      file.file,
      String(sampleDuration),
      String(confidence),
      String(dryRun),
      String(backup),
    ]
      .map((s) => (/\s/.test(s) ? `"${s}"` : s))
      .join(" ");

    response.infoLog += `🔎 Running detection: ${cmd}\n`;
    const out = execSync(cmd, {
      encoding: "utf8",
      maxBuffer: 10 * 1024 * 1024,
    });
    let parsed = {};
    try {
      parsed = JSON.parse(out);
    } catch (e) {
      response.error = true;
      response.infoLog += `❌ Failed to parse JSON from detection script: ${e.message}\nOutput:\n${out}\n`;
      return response;
    }

    response.infoLog += `📊 Detection result:\n${JSON.stringify(
      parsed,
      null,
      2
    )}\n`;

    if (parsed.errors && parsed.errors.length) {
      response.infoLog += `⚠️ Script reported errors: ${JSON.stringify(
        parsed.errors
      )}\n`;
    }

    if (parsed.changes_made) {
      response.infoLog += "✅ Changes applied (metadata-only)\n";
    } else {
      response.infoLog += "ℹ️ No metadata changes required or dry-run\n";
    }
  } catch (err) {
    response.error = true;
    response.infoLog += `❌ Exception: ${err.message}\n`;
  }

  return response;
};
