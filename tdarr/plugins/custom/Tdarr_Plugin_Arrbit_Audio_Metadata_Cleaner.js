const details = () => ({
  id: "Tdarr_Plugin_CGEDIT_Audio_Metadata_Cleaner",
  Stage: "Pre-processing",
  Name: "CGEDIT Clean Audio Title Metadata",
  Type: "Video",
  Operation: "Transcode",
  Description:
    "This plugin removes title metadata from audio streams, with the ability to ignore specified words.\n\n",
  Version: "2.4",
  Tags: "pre-processing,ffmpeg,configurable",
  Inputs: [
    {
      name: "allowed_words",
      type: "string",
      defaultValue: "",
      inputUI: {
        type: "text",
      },
      tooltip: `
 Specify words to ignore when cleaning audio title metadata.
 \\nComma-separated list. Case-insensitive.
 \\nExample:\\n
 \\ncastellano,english,forced
    `,
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
    FFmpegMode: true,
    reQueueAfter: false,
    infoLog: "",
  };

  let ffmpegCommandInsert = "";
  let audioIdx = 0;
  let convert = false;

  // Parse allowed words into an array, trimming whitespace and converting to lowercase
  let allowedWords = [];
  if (inputs.allowed_words && inputs.allowed_words.trim() !== "") {
    allowedWords = inputs.allowed_words
      .toLowerCase()
      .split(",")
      .map((word) => word.trim());
  }

  // Check if the file is a video
  if (file.fileMedium !== "video") {
    console.log("File is not video");
    response.infoLog += "☒ File is not video\n";
    return response;
  }

  // Iterate through all streams in the file
  for (let i = 0; i < file.ffProbeData.streams.length; i += 1) {
    const stream = file.ffProbeData.streams[i];

    // Target audio streams
    if (stream.codec_type.toLowerCase() === "audio") {
      try {
        const title = stream.tags?.title;

        if (title && title !== '""' && title !== "") {
          const titleLower = title.toLowerCase();

          // Check if title contains any of the allowed words
          const shouldIgnore = allowedWords.some((word) =>
            titleLower.includes(word),
          );

          if (shouldIgnore) {
            response.infoLog += `✅ Skipping audio stream ${i} due to allowed word match.\n`;
          } else {
            // Remove the title metadata from the audio stream
            response.infoLog += `☒ Removing title from audio stream ${i}.\n`;
            ffmpegCommandInsert += ` -metadata:s:a:${audioIdx} title= `;
            convert = true;
          }
        }
        audioIdx += 1;
      } catch (err) {
        console.error(`Error processing audio title metadata: ${err}`);
      }
    }
  }

  // If any audio titles were removed, set up the FFmpeg command
  if (convert === true) {
    response.infoLog += "☒ Audio title metadata detected and removed.\n";
    response.preset = `,${ffmpegCommandInsert} -c copy -map 0 -max_muxing_queue_size 9999`;
    response.reQueueAfter = true;
    response.processFile = true;
  } else {
    response.infoLog += "☑ No audio title metadata to remove.\n";
  }

  return response;
};

module.exports.details = details;
module.exports.plugin = plugin;
