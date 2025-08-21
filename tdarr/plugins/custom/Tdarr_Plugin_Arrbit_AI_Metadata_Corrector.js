const details = () => ({
  id: "Tdarr_Plugin_Arrbit_AI_Metadata_Corrector",
  Stage: "Pre-processing",
  Name: "Arrbit - AI Metadata Corrector",
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
  // NOTE: The detection JSON is treated as the authoritative source of truth
  // for the spoken language of each audio stream. We do NOT attempt to
  // parse or reconcile stream title metadata (e.g., "English 5.1 Surround").
  // Any mismatch between existing language tags and detected languages will
  // result in updating the language tag to match the detection output.
    const streams = file.ffProbeData.streams || [];

    // helper: normalize various language outputs to ffmpeg-friendly ISO 639 three-letter codes
    const langMap = {
      en: "eng",
      eng: "eng",
      english: "eng",
      es: "spa",
      spa: "spa",
      spanish: "spa",
      fr: "fra",
      fra: "fra",
      fre: "fra",
      french: "fra",
      pt: "por",
      por: "por",
      portuguese: "por",
      it: "ita",
      ita: "ita",
      italian: "ita",
      de: "deu",
      deu: "deu",
      ger: "deu",
      german: "deu",
      ja: "jpn",
      jpn: "jpn",
      japanese: "jpn",
      ko: "kor",
      kor: "kor",
      korean: "kor",
      zh: "zho",
      zho: "zho",
      chinese: "zho",
      ru: "rus",
      rus: "rus",
      russian: "rus",
      ar: "ara",
      ara: "ara",
      arabic: "ara",
      hi: "hin",
      hin: "hin",
      hindi: "hin",
      nl: "nld",
      nld: "nld",
      dutch: "nld",
      sv: "swe",
      swe: "swe",
      swedish: "swe",
      no: "nor",
      nor: "nor",
      norwegian: "nor",
      fi: "fin",
      fin: "fin",
      finnish: "fin",
      pl: "pol",
      pol: "pol",
      polish: "pol",
      tr: "tur",
      tur: "tur",
      turkish: "tur",
      vi: "vie",
      vie: "vie",
      vietnamese: "vie",
    };

    const normalizeLanguage = (raw) => {
      if (!raw || typeof raw !== "string") return null;
      const key = raw.trim().toLowerCase();
      if (langMap[key]) return langMap[key];
      // if it's a 2-letter code not in map, try common expansion
      if (/^[a-z]{2}$/.test(key)) {
        // naive mapping table for two letters
        const twoToThree = {
          en: "eng",
          es: "spa",
          fr: "fra",
          pt: "por",
          it: "ita",
          de: "deu",
        };
        if (twoToThree[key]) return twoToThree[key];
      }
      // if already 3-letter, return as-is
      if (/^[a-z]{3}$/.test(key)) return key;
      return null;
    };

    // Build ffmpeg metadata edits based on mismatches
    let ffmpegMetaEdits = "";
    let audioStreamOutputIndex = 0;
    let convertNeeded = false;

    streams.forEach((stream) => {
      if (stream.codec_type && stream.codec_type.toLowerCase() === "audio") {
        const idx = stream.index; // input stream index
        const ai = results[idx];
        const detectedRaw = ai && ai.language ? ai.language : null;
        const detected = normalizeLanguage(detectedRaw);
        const currentLangRaw =
          stream.tags &&
          (stream.tags.language || stream.tags.LANGUAGE || stream.tags.lang)
            ? stream.tags.language || stream.tags.LANGUAGE || stream.tags.lang
            : null;
        const currentLang = normalizeLanguage(currentLangRaw);

        if (detected && currentLang && detected === currentLang) {
          response.infoLog += `☑ Audio stream ${idx} language matches detected (${detected}).\n`;
        } else if (detected && detected !== currentLang) {
          response.infoLog += `☒ Audio stream ${idx} language tag mismatch (ignoring any title text): current='${currentLangRaw}' detected='${detectedRaw}' — scheduling authoritative update.\n`;
          ffmpegMetaEdits += ` -metadata:s:a:${audioStreamOutputIndex} language=${detected}`;
          convertNeeded = true;
        } else {
          response.infoLog += `⚠ Could not determine detected language for stream ${idx} (raw: ${detectedRaw}).\n`;
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
