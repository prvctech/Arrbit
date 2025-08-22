const details = () => ({
  id: "Tdarr_Plugin_Arrbit_AI_Metadata_Corrector",
  Stage: "Pre-processing",
  Name: "Arrbit - AI Metadata Corrector",
  Type: "Audio",
  Operation: "Transcode",
  Description:
    "Reads a <file>.ai_lang.json produced by the AI Language Detection plugin and, when mismatches between detected and tagged languages are found, updates the MKV audio track language metadata using ffmpeg.",
  Version: "0.5",
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

    // Quick sanity: list AI languages detected
    const detectedSummary = Object.keys(results)
      .map(
        (k) =>
          `${k}:${
            results[k] && results[k].language ? results[k].language : "?"
          }`
      )
      .join(", ");
    response.infoLog += `AI detected languages (by input stream index): ${detectedSummary} (convert known 2->3; unknown 2-letter passed through)\n`;

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
      th: "tha",
      tha: "tha",
      thai: "tha",
      el: "ell",
      ell: "ell",
      greek: "ell",
      uk: "ukr",
      ukr: "ukr",
      ukrainian: "ukr",
      cs: "ces",
      ces: "ces",
      cze: "ces",
      czech: "ces",
      sk: "slk",
      slk: "slk",
      slo: "slk",
      slovak: "slk",
      hu: "hun",
      hun: "hun",
      hungarian: "hun",
      ro: "ron",
      ron: "ron",
      rum: "ron",
      romanian: "ron",
      bg: "bul",
      bul: "bul",
      bulgarian: "bul",
      sr: "srp",
      srp: "srp",
      serbian: "srp",
      hr: "hrv",
      hrv: "hrv",
      croatian: "hrv",
      da: "dan",
      dan: "dan",
      danish: "dan",
      he: "heb",
      heb: "heb",
      hebrew: "heb",
      fa: "fas",
      fas: "fas",
      per: "fas",
      persian: "fas",
      ur: "urd",
      urd: "urd",
      urdu: "urd",
    };

    const normalizeLanguage = (raw) => {
      if (!raw || typeof raw !== "string") return null;
      const key = raw.trim().toLowerCase();
      if (langMap[key]) return langMap[key];
      if (/^[a-z]{2}$/.test(key)) {
        const twoToThree = {
          en: "eng",
          es: "spa",
          fr: "fra",
          pt: "por",
          it: "ita",
          de: "deu",
          ja: "jpn",
          ko: "kor",
          zh: "zho",
          ru: "rus",
          ar: "ara",
          hi: "hin",
          nl: "nld",
          sv: "swe",
          no: "nor",
          fi: "fin",
          pl: "pol",
          tr: "tur",
          vi: "vie",
          th: "tha",
          el: "ell",
          uk: "ukr",
          cs: "ces",
          sk: "slk",
          hu: "hun",
          ro: "ron",
          bg: "bul",
          sr: "srp",
          hr: "hrv",
          da: "dan",
          he: "heb",
          fa: "fas",
          ur: "urd",
        };
        return twoToThree[key] || key; // pass through unknown 2-letter
      }
      if (/^[a-z]{3}$/.test(key)) return key;
      return null;
    };

    // Build ffmpeg metadata edits based on mismatches
    let ffmpegMetaEdits = [];
    let audioStreamOutputIndex = 0; // counts only audio streams in output order
    let convertNeeded = false;

    streams.forEach((stream) => {
      if (
        !stream ||
        !stream.codec_type ||
        stream.codec_type.toLowerCase() !== "audio"
      )
        return;
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
        response.infoLog += `☑ Stream ${idx} OK (audio output #${audioStreamOutputIndex}) current='${currentLangRaw}' detected='${detectedRaw}'.\n`;
      } else if (detected && (!currentLang || detected !== currentLang)) {
        response.infoLog += `✎ Stream ${idx} will be retagged (audio output #${audioStreamOutputIndex}) current='${currentLangRaw}' => '${detectedRaw}'.\n`;
        ffmpegMetaEdits.push(
          `-metadata:s:a:${audioStreamOutputIndex} language=${detected}`
        );
        convertNeeded = true;
      } else {
        response.infoLog += `⚠ Stream ${idx} unable to determine detected language (raw='${detectedRaw}'). Skipping.\n`;
      }

      audioStreamOutputIndex += 1;
    });

    if (convertNeeded && ffmpegMetaEdits.length > 0) {
      const metaArgs = ffmpegMetaEdits.join(" ");
      // Use comma prefix for consistency with other local plugins so presets chain cleanly.
      const ffmpegPreset = `, ${metaArgs} -c copy -map 0 -max_muxing_queue_size 9999`;
      response.preset = ffmpegPreset;
      response.reQueueAfter = true;
      response.processFile = true;
      response.infoLog += `☑ Scheduled ffmpeg metadata rewrite with args: ${metaArgs}\n`;
    } else if (convertNeeded && ffmpegMetaEdits.length === 0) {
      response.infoLog +=
        "⚠ convertNeeded true but no metadata edits collected; skipping.\n";
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
