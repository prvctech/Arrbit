/* eslint-disable */
const details = () => ({
  id: 'Tdarr_Plugin_Arrbit_Language_Detection',
  Stage: 'Pre-processing',
  Name: 'Arrbit Language Detection',
  Type: 'Audio',
  Operation: 'Transcode',
  Description:
    'This plugin detects the language of audio tracks using WhisperX and tags them accordingly. It uses mkvpropedit for efficient tagging of MKV files and falls back to ffmpeg for other containers.',
  Version: '1.0',
  Tags: 'pre-processing,audio,language detection,whisperx,mkvpropedit,ffmpeg',
  Inputs: [],
});

// IMPORTANT: This plugin requires the ability to execute external commands.
// The standard Tdarr plugin environment may not allow this for security reasons.
// The use of 'child_process' here is a placeholder for a Tdarr-approved mechanism
// for running shell scripts. If this plugin fails to run, it is likely because
// the Tdarr environment does not support 'child_process.execSync'.
// You may need to use a different type of plugin or a custom Tdarr Flow action
// to execute the necessary scripts.
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const plugin = (file, librarySettings, inputs, otherArguments) => {
  const response = {
    processFile: false,
    preset: '',
    container: `.${file.container}`,
    handBrakeMode: false,
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: '',
  };

  if (file.fileMedium !== 'video') {
    response.infoLog += '☒ File is not a video.\n';
    return response;
  }

  const workDir = '/app/arrbit/tdarr/data/temp';
  const scriptPath = '/app/arrbit/tdarr/scripts/transcribe_audio.bash';
  let ffmpegCommand = '';
  let changesMade = false;

  const audioStreams = file.ffProbeData.streams.filter(
    (stream) => stream.codec_type === 'audio',
  );

  for (const stream of audioStreams) {
    const streamIndex = stream.index;
    const language = (stream.tags && stream.tags.language) || 'und';

    response.infoLog += `Processing stream ${streamIndex} with language '${language}'\n`;

    const tempAudioFile = path.join(workDir, `${path.basename(file.file, path.extname(file.file))}_${streamIndex}.mka`);
    const langFile = path.join(workDir, `${path.basename(file.file, path.extname(file.file))}_${streamIndex}.lang`);

    try {
      // 1. Extract audio
      response.infoLog += `Extracting stream ${streamIndex} to ${tempAudioFile}\n`;
      execSync(`ffmpeg -i "${file.file}" -map 0:${streamIndex} -c:a copy "${tempAudioFile}" -y`);

      // 2. Run transcription script
      response.infoLog += `Running language detection on ${tempAudioFile}\n`;
      execSync(`bash ${scriptPath} "${tempAudioFile}"`);

      // 3. Read detected language
      if (fs.existsSync(langFile)) {
        const langOutput = fs.readFileSync(langFile, 'utf-8');
        const match = langOutput.match(/Detected language: ([a-z]{2})/);
        if (match && match[1]) {
          const detectedLang = match[1];
          response.infoLog += `Detected language: ${detectedLang}\n`;

          if (detectedLang !== language) {
            // 4. Tag language
            if (file.container === 'mkv') {
              response.infoLog += `Tagging stream ${streamIndex} with language '${detectedLang}' using mkvpropedit\n`;
              execSync(`mkvpropedit "${file.file}" --edit track:${streamIndex + 1} --set language=${detectedLang}`);
              changesMade = true;
            } else {
              // For non-mkv files, we need to build an ffmpeg command
              response.infoLog += `Tagging stream ${streamIndex} with language '${detectedLang}' using ffmpeg\n`;
              ffmpegCommand += `-c:a:${stream.index} copy -metadata:s:a:${stream.index} language=${detectedLang} `;
            }
          } else {
            response.infoLog += `Language is already correct for stream ${streamIndex}.\n`;
          }
        } else {
          response.infoLog += `Could not determine language for stream ${streamIndex}.\n`;
        }
      } else {
        response.infoLog += `Language file not found for stream ${streamIndex}.\n`;
      }
    } catch (e) {
      response.infoLog += `Error processing stream ${streamIndex}: ${e.message}\n`;
    } finally {
      // 5. Clean up temporary files
      if (fs.existsSync(tempAudioFile)) fs.unlinkSync(tempAudioFile);
      if (fs.existsSync(langFile)) fs.unlinkSync(langFile);
      const txtFile = langFile.replace('.lang', '.txt');
      if (fs.existsSync(txtFile)) fs.unlinkSync(txtFile);
    }
  }

  if (ffmpegCommand) {
    response.processFile = true;
    response.preset = `-map 0 ${ffmpegCommand} -c:v copy -c:s copy`;
    response.reQueueAfter = true;
    changesMade = true;
  }

  if (changesMade) {
    response.infoLog += '✔ Language detection and tagging complete.\n';
  } else {
    response.infoLog += '☑ No language changes were necessary.\n';
  }

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;
