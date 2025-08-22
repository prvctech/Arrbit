const details = () => ({
  id: "Tdarr_Plugin_Arrbit_AI_Language_Detection_v2",
  Stage: "Pre-processing",
  Name: "Arrbit - AI Language Detection v2 (VAD + Probability Aggregation)",
  Type: "Audio",
  Operation: "Transcode",
  Description:
    "Advanced language detection using Voice Activity Detection to sample speech segments across the entire track. Aggregates probability distributions from multiple segments for robust detection with confidence scoring.",
  Version: "2.0",
  Tags: "pre-processing,ai,whisperx,language-detection,vad,probability",
  Inputs: [
    {
      name: "target_speech_duration",
      type: "number",
      defaultValue: 90,
      inputUI: { type: "number", placeholder: "90", allowCustom: true },
      tooltip:
        "Target total seconds of speech to analyze (60-120 recommended). Will spread samples across the track.",
    },
    {
      name: "min_segment_length",
      type: "number",
      defaultValue: 3,
      inputUI: { type: "number", placeholder: "3", allowCustom: true },
      tooltip:
        "Minimum length in seconds for each speech segment (default 3s).",
    },
    {
      name: "max_segment_length",
      type: "number",
      defaultValue: 15,
      inputUI: { type: "number", placeholder: "15", allowCustom: true },
      tooltip:
        "Maximum length in seconds for each speech segment (default 15s).",
    },
    {
      name: "vad_threshold",
      type: "number",
      defaultValue: 0.5,
      inputUI: { type: "number", placeholder: "0.5", allowCustom: true },
      tooltip:
        "Voice Activity Detection threshold (0.0-1.0). Higher = more strict speech detection.",
    },
    {
      name: "confidence_high_threshold",
      type: "number",
      defaultValue: 0.8,
      inputUI: { type: "number", placeholder: "0.80", allowCustom: true },
      tooltip:
        "High confidence threshold (0.0-1.0). Above this = definitive language tag.",
    },
    {
      name: "confidence_medium_threshold",
      type: "number",
      defaultValue: 0.55,
      inputUI: { type: "number", placeholder: "0.55", allowCustom: true },
      tooltip:
        "Medium confidence threshold (0.0-1.0). Above this = likely correct, below = ambiguous.",
    },
    {
      name: "early_exit_threshold",
      type: "number",
      defaultValue: 0.85,
      inputUI: { type: "number", placeholder: "0.85", allowCustom: true },
      tooltip:
        "Early exit threshold (0.0-1.0). Stop processing when confidence exceeds this after minimum duration.",
    },
    {
      name: "min_duration_before_exit",
      type: "number",
      defaultValue: 30,
      inputUI: { type: "number", placeholder: "30", allowCustom: true },
      tooltip:
        "Minimum seconds of speech to analyze before allowing early exit.",
    },
    {
      name: "prefer_center_channel",
      type: "boolean",
      defaultValue: true,
      inputUI: { type: "checkbox" },
      tooltip:
        "For multichannel audio, prefer center channel (FC) for speech extraction.",
    },
    {
      name: "use_subtitle_priors",
      type: "boolean",
      defaultValue: true,
      inputUI: { type: "checkbox" },
      tooltip:
        "Use existing subtitle tracks as language priors for validation.",
    },
    {
      name: "cleanup_intermediate",
      type: "boolean",
      defaultValue: true,
      inputUI: { type: "checkbox" },
      tooltip: "Remove intermediate audio files after processing.",
    },
    {
      name: "whisperx_path",
      type: "string",
      defaultValue: "/app/arrbit/environments/whisperx-env/bin/whisperx",
      inputUI: { type: "text", allowCustom: true },
      tooltip: "Path to whisperx executable.",
    },
    {
      name: "model",
      type: "string",
      defaultValue: "base",
      inputUI: { type: "text", placeholder: "base", allowCustom: true },
      tooltip:
        "WhisperX model size (base recommended for multilingual accuracy).",
    },
    {
      name: "compute_type",
      type: "string",
      defaultValue: "float32",
      inputUI: { type: "text", placeholder: "float32", allowCustom: true },
      tooltip: "Compute precision (float32 for CPU compatibility).",
    },
    {
      name: "max_processing_time",
      type: "number",
      defaultValue: 300,
      inputUI: { type: "number", placeholder: "300", allowCustom: true },
      tooltip: "Maximum total processing time in seconds before timeout.",
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
    const subtitleStreams = streams.filter(
      (s) => s.codec_type && s.codec_type.toLowerCase() === "subtitle"
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
    const sourcePath = file.path || file.file || file.fileName || file.name;

    if (!sourcePath) {
      response.infoLog += "☒ Source path unavailable. Skipping.\n";
      return response;
    }

    const duration = Number(file.ffProbeData?.format?.duration) || 0;
    const targetSpeechDuration = Math.max(
      30,
      Math.min(300, Number(inputs.target_speech_duration) || 90)
    );
    const minSegmentLength = Math.max(
      1,
      Number(inputs.min_segment_length) || 3
    );
    const maxSegmentLength = Math.max(
      minSegmentLength + 1,
      Number(inputs.max_segment_length) || 15
    );
    const vadThreshold = Math.max(
      0.1,
      Math.min(0.9, Number(inputs.vad_threshold) || 0.5)
    );
    const confidenceHighThreshold =
      Number(inputs.confidence_high_threshold) || 0.8;
    const confidenceMediumThreshold =
      Number(inputs.confidence_medium_threshold) || 0.55;
    const earlyExitThreshold = Number(inputs.early_exit_threshold) || 0.85;
    const minDurationBeforeExit = Number(inputs.min_duration_before_exit) || 30;

    response.infoLog += `ℹ Advanced detection: target=${targetSpeechDuration}s speech, VAD=${vadThreshold}, confidence thresholds=${confidenceMediumThreshold}/${confidenceHighThreshold}, early_exit=${earlyExitThreshold}\n`;

    const results = {};

    // Extract subtitle language priors if enabled
    const subtitlePriors = new Set();
    if (inputs.use_subtitle_priors !== false && subtitleStreams.length > 0) {
      subtitleStreams.forEach((sub) => {
        const lang = sub.tags?.language || sub.tags?.LANGUAGE || sub.tags?.lang;
        if (lang && lang !== "und" && !isCommentaryTrack(sub)) {
          subtitlePriors.add(lang.toLowerCase().slice(0, 3)); // normalize to 3-char max
        }
      });
      if (subtitlePriors.size > 0) {
        response.infoLog += `ℹ Subtitle language priors: ${Array.from(
          subtitlePriors
        ).join(", ")}\n`;
      }
    }

    for (let streamIdx = 0; streamIdx < audioStreams.length; streamIdx++) {
      const stream = audioStreams[streamIdx];

      // Skip commentary tracks
      if (isCommentaryTrack(stream)) {
        response.infoLog += `⏭ Skipping commentary track ${streamIdx}\n`;
        results[stream.index] = {
          skipped: true,
          reason: "commentary_track",
          track_title: stream.tags?.title || stream.tags?.TITLE || "unnamed",
        };
        continue;
      }

      try {
        const streamResult = processAudioStreamAdvanced({
          stream,
          streamIdx,
          sourcePath,
          duration,
          tempDir,
          fileBasename,
          targetSpeechDuration,
          minSegmentLength,
          maxSegmentLength,
          vadThreshold,
          confidenceHighThreshold,
          confidenceMediumThreshold,
          earlyExitThreshold,
          minDurationBeforeExit,
          subtitlePriors,
          inputs,
          response,
        });

        results[stream.index] = streamResult;
      } catch (error) {
        response.infoLog += `☒ Failed to process stream ${streamIdx}: ${error.message}\n`;
        results[stream.index] = {
          error: "processing_failed",
          error_details: error.message,
        };
      }
    }

    // Write enhanced results
    const resultsPath = `${tempDir}/${fileBasename}.ai_lang.json`;
    const enhancedResults = {
      file: sourcePath,
      processing_timestamp: new Date().toISOString(),
      detection_version: "2.0",
      parameters: {
        target_speech_duration: targetSpeechDuration,
        vad_threshold: vadThreshold,
        confidence_thresholds: {
          high: confidenceHighThreshold,
          medium: confidenceMediumThreshold,
          early_exit: earlyExitThreshold,
        },
        subtitle_priors: Array.from(subtitlePriors),
      },
      results: results,
    };

    try {
      fs.writeFileSync(resultsPath, JSON.stringify(enhancedResults, null, 2));
      response.infoLog += `☑ Enhanced detection results written to ${resultsPath}\n`;
    } catch (e) {
      response.infoLog += `☒ Failed to write results: ${e}\n`;
    }

    response.infoLog += "✔ Advanced AI language detection completed.\n";
    return response;
  } catch (err) {
    response.infoLog += `☒ Unexpected error: ${err}\n`;
    return response;
  }
};

// Helper function to detect commentary tracks
function isCommentaryTrack(stream) {
  const title = (stream.tags?.title || stream.tags?.TITLE || "").toLowerCase();
  const commentaryKeywords = [
    "commentary",
    "director",
    "producer",
    "cast",
    "crew",
    "behind",
    "making",
  ];
  return commentaryKeywords.some((keyword) => title.includes(keyword));
}

// Advanced audio stream processing with VAD and probability aggregation
function processAudioStreamAdvanced(params) {
  const {
    stream,
    streamIdx,
    sourcePath,
    duration,
    tempDir,
    fileBasename,
    targetSpeechDuration,
    minSegmentLength,
    maxSegmentLength,
    vadThreshold,
    confidenceHighThreshold,
    confidenceMediumThreshold,
    earlyExitThreshold,
    minDurationBeforeExit,
    subtitlePriors,
    inputs,
    response,
  } = params;

  const streamIndex = stream.index;
  const startTime = Date.now();

  // Step 1: Extract full audio for VAD analysis
  const fullAudioPath = `${tempDir}/${fileBasename}_stream${streamIdx}_full.wav`;
  const channelLayout = stream.channel_layout || stream.channels;

  // Determine extraction strategy based on channel layout
  let extractCmd;
  if (
    inputs.prefer_center_channel !== false &&
    (channelLayout === "5.1" ||
      channelLayout === "5.1(side)" ||
      channelLayout === "7.1" ||
      String(stream.channels) === "6")
  ) {
    // Try center channel extraction first
    extractCmd = `ffmpeg -y -i "${sourcePath}" -map 0:${streamIndex} -vn -filter_complex "pan=mono|c0=FC" -ar 16000 -ac 1 -c:a pcm_s16le "${fullAudioPath}"`;
    response.infoLog += `☑ Extracting center channel from stream ${streamIdx} for VAD\n`;
  } else {
    extractCmd = `ffmpeg -y -i "${sourcePath}" -map 0:${streamIndex} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${fullAudioPath}"`;
    response.infoLog += `☑ Extracting mono downmix from stream ${streamIdx} for VAD\n`;
  }

  try {
    child.execSync(extractCmd, { stdio: "pipe", timeout: 120000 });
  } catch (error) {
    // Fallback to standard mono downmix
    const fallbackCmd = `ffmpeg -y -i "${sourcePath}" -map 0:${streamIndex} -vn -ac 1 -ar 16000 -c:a pcm_s16le "${fullAudioPath}"`;
    response.infoLog += `⚠ Center channel extraction failed, using fallback for stream ${streamIdx}\n`;
    child.execSync(fallbackCmd, { stdio: "pipe", timeout: 120000 });
  }

  // Step 2: Run VAD to find speech segments
  response.infoLog += `☑ Running VAD analysis on stream ${streamIdx}\n`;
  const speechSegments = runVADAnalysis(
    fullAudioPath,
    vadThreshold,
    minSegmentLength,
    maxSegmentLength,
    duration,
    inputs
  );

  if (speechSegments.length === 0) {
    return {
      language: "und",
      confidence: 0.0,
      confidence_tier: "no_speech",
      speech_segments_found: 0,
      total_speech_duration: 0,
      reason: "no_speech_detected",
    };
  }

  response.infoLog += `☑ Found ${
    speechSegments.length
  } speech segments (${speechSegments
    .reduce((sum, seg) => sum + seg.duration, 0)
    .toFixed(1)}s total)\n`;

  // Step 3: Select representative segments across the track
  const selectedSegments = selectRepresentativeSegments(
    speechSegments,
    targetSpeechDuration,
    duration
  );
  response.infoLog += `☑ Selected ${
    selectedSegments.length
  } segments for analysis (${selectedSegments
    .reduce((sum, seg) => sum + seg.duration, 0)
    .toFixed(1)}s)\n`;

  // Step 4: Process each segment and aggregate probabilities
  const languageProbabilities = new Map();
  const segmentResults = [];
  let totalSpeechAnalyzed = 0;
  let shouldEarlyExit = false;

  for (let i = 0; i < selectedSegments.length && !shouldEarlyExit; i++) {
    const segment = selectedSegments[i];
    const segmentPath = `${tempDir}/${fileBasename}_stream${streamIdx}_seg${i}.wav`;

    // Extract segment
    const segmentCmd = `ffmpeg -y -i "${fullAudioPath}" -ss ${segment.start} -t ${segment.duration} -c:a pcm_s16le "${segmentPath}"`;
    child.execSync(segmentCmd, { stdio: "pipe", timeout: 30000 });

    // Run WhisperX on segment
    const segmentResult = runWhisperXOnSegment(segmentPath, inputs, response);
    segmentResults.push({
      segment_index: i,
      start_time: segment.start,
      duration: segment.duration,
      ...segmentResult,
    });

    // Aggregate probabilities
    if (segmentResult.language_probabilities) {
      for (const [lang, prob] of Object.entries(
        segmentResult.language_probabilities
      )) {
        const weightedProb = prob * segment.duration; // weight by duration
        languageProbabilities.set(
          lang,
          (languageProbabilities.get(lang) || 0) + weightedProb
        );
      }
    } else if (segmentResult.language && segmentResult.language !== "und") {
      // Fallback: treat single language as 100% probability
      const weightedProb = 1.0 * segment.duration;
      languageProbabilities.set(
        segmentResult.language,
        (languageProbabilities.get(segmentResult.language) || 0) + weightedProb
      );
    }

    totalSpeechAnalyzed += segment.duration;

    // Check for early exit
    if (
      totalSpeechAnalyzed >= minDurationBeforeExit &&
      languageProbabilities.size > 0
    ) {
      const totalWeight = Array.from(languageProbabilities.values()).reduce(
        (sum, weight) => sum + weight,
        0
      );
      if (totalWeight > 0) {
        const topLanguage = Array.from(languageProbabilities.entries()).reduce(
          (max, [lang, weight]) => (weight > max[1] ? [lang, weight] : max),
          ["", 0]
        );
        const topConfidence = topLanguage[1] / totalWeight;

        if (topConfidence >= earlyExitThreshold) {
          response.infoLog += `☑ Early exit triggered: ${topLanguage[0]} at ${(
            topConfidence * 100
          ).toFixed(1)}% confidence after ${totalSpeechAnalyzed.toFixed(1)}s\n`;
          shouldEarlyExit = true;
        }
      }
    }

    // Cleanup segment file
    if (inputs.cleanup_intermediate !== false) {
      try {
        fs.unlinkSync(segmentPath);
      } catch (e) {}
    }
  }

  // Step 5: Compute final results
  const totalWeight = Array.from(languageProbabilities.values()).reduce(
    (sum, weight) => sum + weight,
    0
  );
  const normalizedProbabilities = {};

  if (totalWeight > 0) {
    for (const [lang, weight] of languageProbabilities.entries()) {
      normalizedProbabilities[lang] = weight / totalWeight;
    }
  }

  // Find primary language
  const sortedLanguages = Object.entries(normalizedProbabilities).sort(
    ([, a], [, b]) => b - a
  );

  const primaryLanguage =
    sortedLanguages.length > 0 ? sortedLanguages[0][0] : "und";
  const primaryConfidence =
    sortedLanguages.length > 0 ? sortedLanguages[0][1] : 0.0;

  // Determine confidence tier
  let confidenceTier;
  if (primaryConfidence >= confidenceHighThreshold) {
    confidenceTier = "high";
  } else if (primaryConfidence >= confidenceMediumThreshold) {
    confidenceTier = "medium";
  } else {
    confidenceTier = "low";
  }

  // Cross-check with subtitle priors
  let subtitleValidation = null;
  if (subtitlePriors.size > 0) {
    const primaryLangNormalized = normalizeLanguageCode(primaryLanguage);
    const hasMatchingSubtitle = Array.from(subtitlePriors).some(
      (subLang) => normalizeLanguageCode(subLang) === primaryLangNormalized
    );

    subtitleValidation = {
      matching_subtitle_found: hasMatchingSubtitle,
      subtitle_languages: Array.from(subtitlePriors),
    };

    if (hasMatchingSubtitle && confidenceTier === "medium") {
      confidenceTier = "high"; // boost confidence when subtitle validates
      response.infoLog += `☑ Confidence boosted by matching subtitle track\n`;
    }
  }

  // Cleanup full audio file
  if (inputs.cleanup_intermediate !== false) {
    try {
      fs.unlinkSync(fullAudioPath);
    } catch (e) {}
  }

  const processingTime = (Date.now() - startTime) / 1000;

  return {
    language: primaryLanguage,
    confidence: primaryConfidence,
    confidence_tier: confidenceTier,
    language_distribution: normalizedProbabilities,
    speech_segments_found: speechSegments.length,
    segments_analyzed: selectedSegments.length,
    total_speech_duration: speechSegments.reduce(
      (sum, seg) => sum + seg.duration,
      0
    ),
    speech_analyzed_duration: totalSpeechAnalyzed,
    early_exit: shouldEarlyExit,
    subtitle_validation: subtitleValidation,
    processing_time_seconds: processingTime,
    segment_details: segmentResults.slice(0, 10), // limit detail output
  };
}

// VAD analysis using Python script
function runVADAnalysis(
  audioPath,
  threshold,
  minLength,
  maxLength,
  totalDuration,
  inputs
) {
  const path = require("path");
  const fs = require("fs");
  const child = require("child_process");

  const vadScript = `
import sys
import torch
import torchaudio
import json
from silero_vad import load_silero_vad, read_audio, get_speech_timestamps

def main():
    model = load_silero_vad()
    wav = read_audio("${audioPath}", sampling_rate=16000)
    
    speech_timestamps = get_speech_timestamps(
        wav, model, 
        threshold=${threshold},
        min_speech_duration_ms=${minLength * 1000},
        max_speech_duration_s=${maxLength}
    )
    
    segments = []
    for speech in speech_timestamps:
        start_sec = speech['start'] / 16000  # convert samples to seconds
        end_sec = speech['end'] / 16000
        duration = end_sec - start_sec
        segments.append({
            "start": start_sec,
            "end": end_sec, 
            "duration": duration
        })
    
    print(json.dumps(segments))

if __name__ == "__main__":
    main()
`;

  const vadScriptPath = `${path.dirname(audioPath)}/vad_analysis.py`;
  fs.writeFileSync(vadScriptPath, vadScript);

  try {
    const pythonPath = inputs.whisperx_path.replace(
      "/bin/whisperx",
      "/bin/python"
    );
    const result = child.execSync(`${pythonPath} ${vadScriptPath}`, {
      encoding: "utf8",
      timeout: 60000,
    });

    const segments = JSON.parse(result.trim());
    return segments;
  } catch (error) {
    console.warn("VAD analysis failed, falling back to uniform sampling");
    // Fallback: create uniform segments
    const numSegments = Math.floor(totalDuration / 30); // 30-second intervals
    const segments = [];
    for (let i = 0; i < numSegments; i++) {
      segments.push({
        start: i * 30,
        end: Math.min((i + 1) * 30, totalDuration),
        duration: Math.min(30, totalDuration - i * 30),
      });
    }
    return segments;
  } finally {
    try {
      fs.unlinkSync(vadScriptPath);
    } catch (e) {}
  }
}

// Select representative segments across the track
function selectRepresentativeSegments(
  speechSegments,
  targetDuration,
  totalDuration
) {
  if (speechSegments.length === 0) return [];

  // Sort by start time
  const sorted = [...speechSegments].sort((a, b) => a.start - b.start);

  // If total speech is less than target, use all segments
  const totalSpeechDuration = sorted.reduce(
    (sum, seg) => sum + seg.duration,
    0
  );
  if (totalSpeechDuration <= targetDuration) {
    return sorted;
  }

  // Distribute segments evenly across the timeline
  const selected = [];
  let remainingDuration = targetDuration;
  const timeSlots = Math.min(8, Math.ceil(targetDuration / 15)); // 8-20 segments, ~15s each
  const slotDuration = totalDuration / timeSlots;

  for (let slot = 0; slot < timeSlots && remainingDuration > 0; slot++) {
    const slotStart = slot * slotDuration;
    const slotEnd = (slot + 1) * slotDuration;

    // Find best segment in this time slot
    const candidatesInSlot = sorted.filter(
      (seg) => seg.start >= slotStart && seg.start < slotEnd
    );

    if (candidatesInSlot.length > 0) {
      // Pick longest segment in slot (more likely to be clean speech)
      const bestSegment = candidatesInSlot.reduce((longest, seg) =>
        seg.duration > longest.duration ? seg : longest
      );

      const segmentDuration = Math.min(bestSegment.duration, remainingDuration);
      selected.push({
        start: bestSegment.start,
        duration: segmentDuration,
        end: bestSegment.start + segmentDuration,
      });

      remainingDuration -= segmentDuration;
    }
  }

  return selected;
}

// Run WhisperX on a single segment
function runWhisperXOnSegment(segmentPath, inputs, response) {
  const path = require("path");
  const fs = require("fs");
  const child = require("child_process");

  const whisperxPath =
    inputs.whisperx_path ||
    "/app/arrbit/environments/whisperx-env/bin/whisperx";
  const model = inputs.model || "base";
  const computeType = inputs.compute_type || "float32";
  const outputDir = path.dirname(segmentPath);

  const whisperArgs = [
    segmentPath,
    "--model",
    model,
    "--device",
    "cpu",
    "--compute_type",
    computeType,
    "--output_dir",
    outputDir,
    "--output_format",
    "json",
    "--task",
    "transcribe",
    "--print_progress",
    "False",
  ];

  try {
    const env = Object.assign({}, process.env, { PYTHONWARNINGS: "ignore" });
    const spawnResult = child.spawnSync(whisperxPath, whisperArgs, {
      encoding: "utf8",
      timeout: 60000,
      env,
    });

    if (spawnResult.status !== 0) {
      return {
        error: "whisperx_failed",
        status: spawnResult.status,
        stderr: spawnResult.stderr?.slice(0, 500),
      };
    }

    // Read WhisperX output
    const jsonPath = `${outputDir}/${path.parse(segmentPath).name}.json`;
    if (fs.existsSync(jsonPath)) {
      try {
        const whisperOutput = JSON.parse(fs.readFileSync(jsonPath, "utf8"));

        // Extract language probabilities if available
        let languageProbabilities = null;
        if (whisperOutput.language_probs) {
          languageProbabilities = whisperOutput.language_probs;
        }

        // Parse detected language from output or segments
        let detectedLanguage = whisperOutput.language || "und";

        // Calculate quality metrics
        const segments = whisperOutput.segments || [];
        let avgLogProb = 0;
        let avgNoSpeechProb = 0;
        let validSegments = 0;

        for (const segment of segments) {
          if (segment.avg_logprob !== undefined) {
            avgLogProb += segment.avg_logprob;
            validSegments++;
          }
          if (segment.no_speech_prob !== undefined) {
            avgNoSpeechProb += segment.no_speech_prob;
          }
        }

        if (validSegments > 0) {
          avgLogProb /= validSegments;
          avgNoSpeechProb /= segments.length;
        }

        // Cleanup JSON file
        try {
          fs.unlinkSync(jsonPath);
        } catch (e) {}

        return {
          language: detectedLanguage,
          language_probabilities: languageProbabilities,
          avg_logprob: avgLogProb,
          avg_no_speech_prob: avgNoSpeechProb,
          segments_count: segments.length,
          has_text: segments.some(
            (seg) => seg.text && seg.text.trim().length > 0
          ),
        };
      } catch (jsonError) {
        return {
          error: "json_parse_failed",
          details: jsonError.message,
        };
      }
    } else {
      return {
        error: "output_missing",
        expected_path: jsonPath,
      };
    }
  } catch (error) {
    return {
      error: "execution_failed",
      details: error.message,
    };
  }
}

// Helper to normalize language codes
function normalizeLanguageCode(code) {
  if (!code) return "und";
  const normalized = code.toLowerCase().slice(0, 3);

  // Common 2->3 letter mappings
  const mapping = {
    en: "eng",
    ja: "jpn",
    zh: "zho",
    ko: "kor",
    es: "spa",
    fr: "fra",
    de: "deu",
    it: "ita",
    pt: "por",
    ru: "rus",
    ar: "ara",
    hi: "hin",
  };

  return mapping[normalized] || normalized;
}

module.exports.details = details;
module.exports.plugin = plugin;
