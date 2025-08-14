const details = () => ({
  id: 'Tdarr_Plugin_audio_language_detector',
  Stage: 'Pre-processing',
  Name: 'Audio Language Detector and Corrector',
  Type: 'Audio',
  Operation: 'Transcode',
  Description: `
    This plugin extracts a 15-second audio sample from each audio track, uses Whisper to detect the language,
    and corrects mislabeled audio track language tags. It helps identify and fix incorrect language tags
    in multi-language videos (e.g., when a Japanese track is incorrectly labeled as English).
    
    Requirements:
    - FFmpeg installed on the system
    - Whisper installed (pip install -U openai-whisper)
    - Temporary directory access for audio samples
  `,
  Version: '1.0',
  Tags: 'pre-processing,ffmpeg,audio,language,whisper',
  Inputs: [
    {
      name: 'whisper_model',
      type: 'string',
      defaultValue: 'tiny',
      inputUI: {
        type: 'dropdown',
        options: [
          'tiny',
          'base',
          'small',
          'medium',
          'large',
        ],
      },
      tooltip: 'Select Whisper model size. Smaller models are faster but less accurate. "tiny" is recommended for language detection.',
    },
    {
      name: 'sample_duration',
      type: 'number',
      defaultValue: 15,
      inputUI: {
        type: 'text',
      },
      tooltip: 'Duration in seconds of audio sample to extract for language detection (default: 15)',
    },
    {
      name: 'sample_start_time',
      type: 'number',
      defaultValue: 60,
      inputUI: {
        type: 'text',
      },
      tooltip: 'Start time in seconds from where to extract the audio sample (default: 60, to avoid intros)',
    },
    {
      name: 'debug',
      type: 'boolean',
      defaultValue: false,
      inputUI: {
        type: 'checkbox',
      },
      tooltip: 'Enable debug logging',
    },
  ],
});

// Helper function to execute shell commands
const executeCommand = (command) => {
  const { execSync } = require('child_process');
  try {
    return execSync(command, { encoding: 'utf8' });
  } catch (error) {
    return { error: error.message };
  }
};

// Helper function to create a temporary directory
const createTempDir = () => {
  const fs = require('fs');
  const path = require('path');
  const os = require('os');
  
  const tempDir = path.join(os.tmpdir(), `tdarr_audio_lang_${Date.now()}`);
  
  if (!fs.existsSync(tempDir)) {
    fs.mkdirSync(tempDir, { recursive: true });
  }
  
  return tempDir;
};

// Helper function to clean up temporary files
const cleanupTempFiles = (tempDir) => {
  const fs = require('fs');
  const { execSync } = require('child_process');
  
  try {
    execSync(`rm -rf "${tempDir}"`);
  } catch (error) {
    // If the command fails, try using Node.js fs
    try {
      fs.rmdirSync(tempDir, { recursive: true });
    } catch (e) {
      // Ignore errors during cleanup
    }
  }
};

// Helper function to detect language using Whisper
const detectLanguageWithWhisper = (audioFile, model) => {
  try {
    // Use Python to run Whisper for language detection
    const pythonScript = `
import whisper
import sys
import json

try:
    # Load audio and model
    audio = whisper.load_audio("${audioFile}")
    audio = whisper.pad_or_trim(audio)
    model = whisper.load_model("${model}")
    
    # Make log-Mel spectrogram
    mel = whisper.log_mel_spectrogram(audio).to(model.device)
    
    # Detect language
    _, probs = model.detect_language(mel)
    detected_lang = max(probs, key=probs.get)
    
    # Get top 3 languages with probabilities for debugging
    top_langs = sorted(probs.items(), key=lambda x: x[1], reverse=True)[:3]
    
    result = {
        "language": detected_lang,
        "confidence": probs[detected_lang],
        "top_languages": {lang: float(prob) for lang, prob in top_langs}
    }
    
    print(json.dumps(result))
except Exception as e:
    print(json.dumps({"error": str(e)}))
`;

    // Save the Python script to a temporary file
    const fs = require('fs');
    const path = require('path');
    const scriptPath = path.join(path.dirname(audioFile), 'detect_language.py');
    fs.writeFileSync(scriptPath, pythonScript);

    // Execute the Python script
    const result = executeCommand(`python3 "${scriptPath}"`);
    
    // Clean up the script file
    try {
      fs.unlinkSync(scriptPath);
    } catch (e) {
      // Ignore errors during cleanup
    }

    // Parse the JSON result
    return JSON.parse(result);
  } catch (error) {
    return { error: `Failed to detect language: ${error.message || error}` };
  }
};

// Helper function to get ISO 639-2 language code from ISO 639-1
const getISO6392Code = (iso6391Code) => {
  const languageMap = {
    'en': 'eng', // English
    'ja': 'jpn', // Japanese
    'zh': 'chi', // Chinese (simplified)
    'ko': 'kor', // Korean
    'fr': 'fre', // French
    'de': 'ger', // German
    'es': 'spa', // Spanish
    'it': 'ita', // Italian
    'ru': 'rus', // Russian
    'pt': 'por', // Portuguese
    'nl': 'dut', // Dutch
    'sv': 'swe', // Swedish
    'no': 'nor', // Norwegian
    'fi': 'fin', // Finnish
    'da': 'dan', // Danish
    'pl': 'pol', // Polish
    'hu': 'hun', // Hungarian
    'cs': 'cze', // Czech
    'tr': 'tur', // Turkish
    'ar': 'ara', // Arabic
    'hi': 'hin', // Hindi
    'th': 'tha', // Thai
    'vi': 'vie', // Vietnamese
    'uk': 'ukr', // Ukrainian
    'el': 'gre', // Greek
    'he': 'heb', // Hebrew
    'id': 'ind', // Indonesian
    'ms': 'may', // Malay
    'ro': 'rum', // Romanian
    'bg': 'bul', // Bulgarian
    'hr': 'hrv', // Croatian
    'sr': 'srp', // Serbian
    'sk': 'slo', // Slovak
    'sl': 'slv', // Slovenian
    'et': 'est', // Estonian
    'lv': 'lav', // Latvian
    'lt': 'lit', // Lithuanian
    'fa': 'per', // Persian
    'ur': 'urd', // Urdu
    'bn': 'ben', // Bengali
    'ta': 'tam', // Tamil
    'te': 'tel', // Telugu
    'mr': 'mar', // Marathi
    'gu': 'guj', // Gujarati
    'kn': 'kan', // Kannada
    'ml': 'mal', // Malayalam
    'si': 'sin', // Sinhala
    'af': 'afr', // Afrikaans
    'sw': 'swa', // Swahili
    'am': 'amh', // Amharic
    'hy': 'arm', // Armenian
    'az': 'aze', // Azerbaijani
    'eu': 'baq', // Basque
    'be': 'bel', // Belarusian
    'ca': 'cat', // Catalan
    'cy': 'wel', // Welsh
    'gl': 'glg', // Galician
    'ka': 'geo', // Georgian
    'is': 'ice', // Icelandic
    'mk': 'mac', // Macedonian
    'mn': 'mon', // Mongolian
    'ne': 'nep', // Nepali
    'pa': 'pan', // Punjabi
    'sq': 'alb', // Albanian
    'tl': 'tgl', // Tagalog
    'uz': 'uzb', // Uzbek
    'zu': 'zul', // Zulu
  };

  return languageMap[iso6391Code] || 'und'; // Return 'und' (undefined) if not found
};

// Helper function to get human-readable language name
const getLanguageName = (iso6391Code) => {
  const languageNames = {
    'en': 'English',
    'ja': 'Japanese',
    'zh': 'Chinese',
    'ko': 'Korean',
    'fr': 'French',
    'de': 'German',
    'es': 'Spanish',
    'it': 'Italian',
    'ru': 'Russian',
    'pt': 'Portuguese',
    'nl': 'Dutch',
    'sv': 'Swedish',
    'no': 'Norwegian',
    'fi': 'Finnish',
    'da': 'Danish',
    'pl': 'Polish',
    'hu': 'Hungarian',
    'cs': 'Czech',
    'tr': 'Turkish',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'th': 'Thai',
    'vi': 'Vietnamese',
    'uk': 'Ukrainian',
    'el': 'Greek',
    'he': 'Hebrew',
    'id': 'Indonesian',
    'ms': 'Malay',
    'ro': 'Romanian',
    'bg': 'Bulgarian',
    'hr': 'Croatian',
    'sr': 'Serbian',
    'sk': 'Slovak',
    'sl': 'Slovenian',
    'et': 'Estonian',
    'lv': 'Latvian',
    'lt': 'Lithuanian',
    'fa': 'Persian',
    'ur': 'Urdu',
    'bn': 'Bengali',
    'ta': 'Tamil',
    'te': 'Telugu',
    'mr': 'Marathi',
    'gu': 'Gujarati',
    'kn': 'Kannada',
    'ml': 'Malayalam',
    'si': 'Sinhala',
    'af': 'Afrikaans',
    'sw': 'Swahili',
    'am': 'Amharic',
    'hy': 'Armenian',
    'az': 'Azerbaijani',
    'eu': 'Basque',
    'be': 'Belarusian',
    'ca': 'Catalan',
    'cy': 'Welsh',
    'gl': 'Galician',
    'ka': 'Georgian',
    'is': 'Icelandic',
    'mk': 'Macedonian',
    'mn': 'Mongolian',
    'ne': 'Nepali',
    'pa': 'Punjabi',
    'sq': 'Albanian',
    'tl': 'Tagalog',
    'uz': 'Uzbek',
    'zu': 'Zulu',
  };

  return languageNames[iso6391Code] || 'Unknown';
};

// Main plugin function
const plugin = (file, librarySettings, inputs, otherArguments) => {
  const lib = require('../methods/lib')();
  inputs = lib.loadDefaultValues(inputs, details);
  
  const response = {
    processFile: false,
    preset: '',
    container: `.${file.container}`,
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: '',
  };

  // Check if file is a video
  if (file.fileMedium !== 'video') {
    response.infoLog += '⚠️ File is not a video. Skipping.\n';
    return response;
  }

  // Check if FFmpeg is installed
  try {
    executeCommand('ffmpeg -version');
  } catch (error) {
    response.infoLog += '❌ FFmpeg is not installed or not in PATH. Plugin cannot run.\n';
    return response;
  }

  // Check if Whisper is installed
  try {
    executeCommand('pip3 show openai-whisper');
  } catch (error) {
    response.infoLog += '❌ Whisper is not installed. Please install with: pip install -U openai-whisper\n';
    return response;
  }

  // Create temporary directory for audio samples
  const tempDir = createTempDir();
  response.infoLog += `📁 Created temporary directory: ${tempDir}\n`;

  // Get audio streams
  const audioStreams = file.ffProbeData.streams.filter(stream => 
    stream.codec_type && stream.codec_type.toLowerCase() === 'audio'
  );

  if (audioStreams.length === 0) {
    response.infoLog += '⚠️ No audio streams found in the file.\n';
    cleanupTempFiles(tempDir);
    return response;
  }

  response.infoLog += `🔍 Found ${audioStreams.length} audio streams. Analyzing...\n`;

  // Process each audio stream
  const streamChanges = [];
  let needsProcessing = false;

  audioStreams.forEach((stream, index) => {
    const streamIndex = stream.index;
    const currentLanguage = stream.tags && stream.tags.language ? stream.tags.language : 'und';
    const currentTitle = stream.tags && stream.tags.title ? stream.tags.title : '';
    
    response.infoLog += `\n📊 Stream #${streamIndex} (${index}): `;
    response.infoLog += `Current language tag: ${currentLanguage}, `;
    response.infoLog += `Title: "${currentTitle}"\n`;

    // Extract audio sample
    const outputFile = `${tempDir}/audio_stream_${streamIndex}.wav`;
    const startTime = inputs.sample_start_time;
    const duration = inputs.sample_duration;
    
    const extractCommand = `ffmpeg -y -i "${file.file}" -map 0:${streamIndex} -ss ${startTime} -t ${duration} -c:a pcm_s16le -ar 16000 -ac 1 "${outputFile}" -v quiet`;
    
    if (inputs.debug) {
      response.infoLog += `🔧 Executing: ${extractCommand}\n`;
    }
    
    const extractResult = executeCommand(extractCommand);
    
    if (extractResult && extractResult.error) {
      response.infoLog += `❌ Failed to extract audio sample from stream #${streamIndex}: ${extractResult.error}\n`;
      return;
    }
    
    response.infoLog += `✅ Extracted ${duration}s audio sample from stream #${streamIndex}\n`;
    
    // Detect language using Whisper
    response.infoLog += `🔍 Detecting language for stream #${streamIndex}...\n`;
    const langResult = detectLanguageWithWhisper(outputFile, inputs.whisper_model);
    
    if (langResult.error) {
      response.infoLog += `❌ Language detection failed for stream #${streamIndex}: ${langResult.error}\n`;
      return;
    }
    
    const detectedLang = langResult.language;
    const detectedLangISO = getISO6392Code(detectedLang);
    const detectedLangName = getLanguageName(detectedLang);
    const confidence = Math.round(langResult.confidence * 100);
    
    response.infoLog += `✅ Detected language: ${detectedLangName} (${detectedLang}/${detectedLangISO}) with ${confidence}% confidence\n`;
    
    if (inputs.debug && langResult.top_languages) {
      response.infoLog += '🔍 Top language matches:\n';
      Object.entries(langResult.top_languages).forEach(([lang, prob]) => {
        const langName = getLanguageName(lang);
        const probability = Math.round(prob * 100);
        response.infoLog += `   - ${langName} (${lang}): ${probability}%\n`;
      });
    }
    
    // Check if language tag needs correction
    if (currentLanguage !== detectedLangISO) {
      response.infoLog += `⚠️ Language mismatch detected! Tag says "${currentLanguage}" but detected "${detectedLangISO}"\n`;
      
      streamChanges.push({
        streamIndex,
        currentLanguage,
        detectedLanguage: detectedLangISO,
        confidence,
      });
      
      needsProcessing = true;
    } else {
      response.infoLog += `✅ Language tag "${currentLanguage}" matches detected language "${detectedLangISO}"\n`;
    }
  });

  // Clean up temporary files
  cleanupTempFiles(tempDir);
  response.infoLog += `🧹 Cleaned up temporary directory\n`;

  // If any streams need correction, build FFmpeg command
  if (needsProcessing) {
    response.processFile = true;
    
    // Start with mapping all streams
    let ffmpegCommand = '-map 0 ';
    
    // Add language metadata corrections
    streamChanges.forEach(change => {
      const { streamIndex, detectedLanguage } = change;
      ffmpegCommand += `-metadata:s:${streamIndex} language=${detectedLanguage} `;
    });
    
    // Copy all codecs
    ffmpegCommand += '-c copy';
    
    response.preset = ffmpegCommand;
    response.infoLog += `\n🔄 Correcting ${streamChanges.length} audio stream language tags\n`;
    response.infoLog += `🔧 FFmpeg command: ${ffmpegCommand}\n`;
  } else {
    response.infoLog += `\n✅ All audio stream language tags are correct. No changes needed.\n`;
  }

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;