// Arrbit Tdarr Plugin - AI Language Detection
// Generates per-audio track LID JSON sidecars using internal Python worker (vad_lid_worker.py)
// Does NOT modify file; second plugin will apply tags.

const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const details = () => ({
  id: "Tdarr_Plugin_Arrbit_AI_Language_Detection",
  Stage: "Pre-processing",
  Name: "Arrbit - AI Language Detection (Sidecar)",
  Type: "Video",
  Operation: "Transcode",
  Description:
    "Detect primary spoken language per audio track via Silero VAD + faster-whisper (tiny int8). Produces JSON sidecars for subsequent metadata tagging.",
  Version: "1.0.0",
  Tags: "analysis,language,ai",
  Inputs: [
    {
      name: "target_speech",
      type: "number",
      defaultValue: 24,
      inputUI: { type: "text" },
      tooltip: "Target speech seconds for sampling (fast mode).",
    },
    {
      name: "window",
      type: "number",
      defaultValue: 3,
      inputUI: { type: "text" },
      tooltip: "Window length seconds.",
    },
    {
      name: "max_windows",
      type: "number",
      defaultValue: 8,
      inputUI: { type: "text" },
      tooltip: "Maximum analysis windows.",
    },
    {
      name: "early",
      type: "number",
      defaultValue: 0.9,
      inputUI: { type: "text" },
      tooltip: "Early exit share threshold.",
    },
    {
      name: "accept",
      type: "number",
      defaultValue: 0.7,
      inputUI: { type: "text" },
      tooltip: "Primary share => accept.",
    },
    {
      name: "ambig_low",
      type: "number",
      defaultValue: 0.55,
      inputUI: { type: "text" },
      tooltip: "Lower bound for ambiguous (mixed).",
    },
  ],
});

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = (file, librarySettings, inputs, otherArguments) => {
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

  if (file.fileMedium !== "video") {
    response.infoLog += "Not a video file.\n";
    return response;
  }
  if (!file.ffProbeData || !file.ffProbeData.streams) {
    response.infoLog += "Missing ffProbeData.\n";
    return response;
  }

  const ARRBIT_BASE = "/app/arrbit";
  const DATA_DIR = path.join(ARRBIT_BASE, "data");
  const TEMP_DIR = path.join(DATA_DIR, "temp");
  try {
    fs.mkdirSync(TEMP_DIR, { recursive: true });
  } catch (_) {}
  const PY = path.join(
    ARRBIT_BASE,
    "environments",
    "whisperx-env",
    "bin",
    "python"
  );
  const WORKER = path.join(
    ARRBIT_BASE,
    "universal",
    "workers",
    "vad_lid_worker.py"
  );
  if (!fs.existsSync(PY) || !fs.existsSync(WORKER)) {
    response.infoLog += "Python env or worker missing.\n";
    return response;
  }

  const baseName = path.basename(file.file); // full path given by Tdarr
  // Build per-audio track sidecars
  let audioTrackIndex = 0;
  for (let i = 0; i < file.ffProbeData.streams.length; i += 1) {
    const s = file.ffProbeData.streams[i];
    if ((s.codec_type || "").toLowerCase() !== "audio") continue;
    const sidecar = path.join(
      TEMP_DIR,
      `${baseName}.a${audioTrackIndex}.lid.json`
    );
    if (fs.existsSync(sidecar)) {
      response.infoLog += `Skip existing LID sidecar a${audioTrackIndex}.\n`;
      audioTrackIndex += 1;
      continue;
    }
    // Extract wav (prefer center channel)
    const wav = path.join(TEMP_DIR, `${baseName}.a${audioTrackIndex}.wav`);
    let ffArgsCenter = [
      "-v",
      "error",
      "-i",
      file.file,
      "-map",
      `0:a:${audioTrackIndex}`,
      "-filter_complex",
      "pan=mono|c0=FC",
      "-ar",
      "16000",
      "-ac",
      "1",
      "-y",
      wav,
    ];
    let r = spawnSync("ffmpeg", ffArgsCenter, { encoding: "utf8" });
    if (r.status !== 0) {
      let ffArgs = [
        "-v",
        "error",
        "-i",
        file.file,
        "-map",
        `0:a:${audioTrackIndex}`,
        "-ar",
        "16000",
        "-ac",
        "1",
        "-y",
        wav,
      ];
      r = spawnSync("ffmpeg", ffArgs, { encoding: "utf8" });
    }
    if (r.status !== 0 || !fs.existsSync(wav)) {
      response.infoLog += `ffmpeg extract failed for track ${audioTrackIndex}.\n`;
      audioTrackIndex += 1;
      continue;
    }
    const args = [
      WORKER,
      wav,
      "--target_speech",
      String(inputs.target_speech),
      "--window",
      String(inputs.window),
      "--max_windows",
      String(inputs.max_windows),
      "--early",
      String(inputs.early),
      "--accept",
      String(inputs.accept),
      "--ambig_low",
      String(inputs.ambig_low),
    ];
    const env = {
      ...process.env,
      TORCH_HOME: path.join(DATA_DIR, "torch"),
      ARRBIT_TORCH_THREADS: "1",
    };
    const wr = spawnSync(PY, args, { encoding: "utf8", env });
    if (wr.status !== 0) {
      response.infoLog += `Worker failed track ${audioTrackIndex}: ${wr.stderr}\n`;
      audioTrackIndex += 1;
      continue;
    }
    try {
      fs.writeFileSync(sidecar, wr.stdout.trim());
      // quick validation
      const parsed = JSON.parse(wr.stdout || "{}");
      if (!parsed.primary) {
        response.infoLog += `Invalid JSON track ${audioTrackIndex}.\n`;
      } else {
        response.infoLog += `Track ${audioTrackIndex} primary=${parsed.primary} share=${parsed.share} decision=${parsed.decision}\n`;
      }
    } catch (e) {
      response.infoLog += `Sidecar write failed track ${audioTrackIndex}: ${e}\n`;
    }
    audioTrackIndex += 1;
  }
  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;
