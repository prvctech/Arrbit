#!/bin/bash
# WhisperX Test Script
# Tests the WhisperX installation in the dedicated environment

WHISPERX_ENV_PATH="/app/services/whisper-x"

echo "=== WhisperX Installation Test ==="

# Check if environment exists
if [[ ! -d "$WHISPERX_ENV_PATH" ]]; then
  echo "❌ WhisperX environment not found at $WHISPERX_ENV_PATH"
  exit 1
fi

# Check if Python exists in environment
if [[ ! -f "$WHISPERX_ENV_PATH/bin/python" ]]; then
  echo "❌ Python not found in WhisperX environment"
  exit 1
fi

# Test WhisperX import
echo "Testing WhisperX import..."
if "$WHISPERX_ENV_PATH/bin/python" -c "import whisperx; print('✅ WhisperX version:', whisperx.__version__)" 2>/dev/null; then
  echo "✅ WhisperX import successful"
else
  echo "❌ WhisperX import failed"
  exit 1
fi

# Test wrapper script
echo "Testing WhisperX wrapper..."
if command -v whisperx >/dev/null 2>&1; then
  echo "✅ WhisperX wrapper script available at: $(which whisperx)"
else
  echo "⚠️  WhisperX wrapper script not in PATH"
fi

# Test basic functionality
echo "Testing WhisperX help..."
if "$WHISPERX_ENV_PATH/bin/python" -m whisperx --help >/dev/null 2>&1; then
  echo "✅ WhisperX command-line interface working"
else
  echo "❌ WhisperX command-line interface failed"
  exit 1
fi

echo ""
echo "🎉 All tests passed! WhisperX is ready to use."
echo "Environment: $WHISPERX_ENV_PATH"
echo "Usage: $WHISPERX_ENV_PATH/bin/python -m whisperx <audio_file>"
echo "   or: whisperx <audio_file> (if wrapper is in PATH)"
