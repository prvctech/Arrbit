// Arrbit Tdarr Plugin - AI Metadata Corrector
// Applies language tags based on previously generated LID sidecar JSON files.

const fs = require("fs");
const path = require("path");

const details = () => ({
  id: "Tdarr_Plugin_Arrbit_AI_Metadata_Corrector",
  Stage: "Pre-processing",
  Name: "Arrbit - AI Language Tag Applier",
  Type: "Video",
  Operation: "Transcode",
  Description:
    "Applies MKV language tags using sidecar LID JSON (primary, ambiguous, review states).",
  Version: "1.0.0",
  Tags: "metadata,language,ai",
  Inputs: [],
});

const isoMap = {
  en: "eng",
  zh: "zho",
  ja: "jpn",
  ko: "kor",
  es: "spa",
  fr: "fra",
  de: "deu",
  it: "ita",
  pt: "por",
  ru: "rus",
  ar: "ara",
  hi: "hin",
  tr: "tur",
  nl: "nld",
  sv: "swe",
  pl: "pol",
  cs: "ces",
  da: "dan",
  fi: "fin",
  el: "ell",
  he: "heb",
  id: "ind",
  ms: "msa",
  no: "nor",
  ro: "ron",
  th: "tha",
  uk: "ukr",
  vi: "vie",
};
const langNames = {
  en: "English",
  zh: "Chinese",
  ja: "Japanese",
  ko: "Korean",
  es: "Spanish",
  fr: "French",
  de: "German",
  it: "Italian",
  pt: "Portuguese",
  ru: "Russian",
  ar: "Arabic",
  hi: "Hindi",
  tr: "Turkish",
  nl: "Dutch",
  sv: "Swedish",
  pl: "Polish",
  cs: "Czech",
  da: "Danish",
  fi: "Finnish",
  el: "Greek",
  he: "Hebrew",
  id: "Indonesian",
  ms: "Malay",
  no: "Norwegian",
  ro: "Romanian",
  th: "Thai",
  uk: "Ukrainian",
  vi: "Vietnamese",
};

// eslint-disable-next-line @typescript-eslint/no-unused-vars
const plugin = (file, librarySettings, inputs, otherArguments) => {
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
  const baseName = path.basename(file.file);

  let audioTrackIdx = 0; // index in ffprobe order of audio
  let ffmpegInsert = "";
  for (let i = 0; i < file.ffProbeData.streams.length; i += 1) {
    const s = file.ffProbeData.streams[i];
    if ((s.codec_type || "").toLowerCase() !== "audio") continue;
    const sidecar = path.join(
      TEMP_DIR,
      `${baseName}.a${audioTrackIdx}.lid.json`
    );
    if (!fs.existsSync(sidecar)) {
      response.infoLog += `No sidecar for a${audioTrackIdx}.\n`;
      audioTrackIdx += 1;
      continue;
    }
    let parsed;
    try {
      parsed = JSON.parse(fs.readFileSync(sidecar, "utf8"));
    } catch (e) {
      response.infoLog += `Invalid JSON for a${audioTrackIdx}.\n`;
      audioTrackIdx += 1;
      continue;
    }
    const primary = (parsed.primary || "").toLowerCase();
    const share = parsed.share || parsed.distribution?.[primary] || 0;
    const decision = parsed.decision || "review";
    if (!primary || !isoMap[primary]) {
      response.infoLog += `No mapping for primary ${primary} track a${audioTrackIdx}.\n`;
      audioTrackIdx += 1;
      continue;
    }
    if (decision === "review") {
      response.infoLog += `Review state a${audioTrackIdx} (no retag).\n`;
      audioTrackIdx += 1;
      continue;
    }
    const iso2 = isoMap[primary];
    const iso1 = primary;
    const mixed = decision === "ambiguous" || (share >= 0.55 && share < 0.7);
    const langName = langNames[primary] || primary;
    ffmpegInsert += ` -metadata:s:a:${audioTrackIdx} language=${iso2} -metadata:s:a:${audioTrackIdx} language-ietf=${iso1}`;
    if (mixed) {
      ffmpegInsert += ` -metadata:s:a:${audioTrackIdx} title='${langName} (mixed)'`;
      response.infoLog += `Tag a${audioTrackIdx} ${iso1}/${iso2} (mixed) share=${share}.\n`;
    } else {
      response.infoLog += `Tag a${audioTrackIdx} ${iso1}/${iso2} share=${share}.\n`;
    }
    audioTrackIdx += 1;
  }

  if (ffmpegInsert) {
    response.processFile = true;
    response.preset = `, -c copy -map 0 ${ffmpegInsert} -max_muxing_queue_size 9999`;
    response.reQueueAfter = true;
  } else {
    response.infoLog += "No tagging operations required.\n";
  }
  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;
