#!/bin/bash

# Installation script for Tdarr Audio Language Detector Plugin dependencies
# This script installs the necessary dependencies for the audio language detector plugin
# Run this script inside your Tdarr Docker container or on your Tdarr server

echo "===== Tdarr Audio Language Detector Plugin - Dependency Installer ====="
echo "This script will install the required dependencies for the audio language detector plugin."
echo "It requires sudo access to install system packages."
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script with sudo or as root."
  exit 1
fi

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check and install FFmpeg
echo "Checking for FFmpeg..."
if command_exists ffmpeg; then
  echo "✅ FFmpeg is already installed."
else
  echo "Installing FFmpeg..."
  if command_exists apt-get; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y ffmpeg
  elif command_exists apk; then
    # Alpine
    apk add --no-cache ffmpeg
  elif command_exists yum; then
    # CentOS/RHEL
    yum install -y epel-release
    yum install -y ffmpeg
  else
    echo "❌ Unsupported package manager. Please install FFmpeg manually."
    exit 1
  fi
  
  if command_exists ffmpeg; then
    echo "✅ FFmpeg installed successfully."
  else
    echo "❌ Failed to install FFmpeg. Please install it manually."
    exit 1
  fi
fi

# Check and install Python
echo "Checking for Python..."
if command_exists python3; then
  echo "✅ Python is already installed."
  PYTHON_CMD="python3"
elif command_exists python; then
  echo "✅ Python is already installed."
  PYTHON_CMD="python"
else
  echo "Installing Python..."
  if command_exists apt-get; then
    # Debian/Ubuntu
    apt-get update
    apt-get install -y python3 python3-pip
    PYTHON_CMD="python3"
  elif command_exists apk; then
    # Alpine
    apk add --no-cache python3 py3-pip
    PYTHON_CMD="python3"
  elif command_exists yum; then
    # CentOS/RHEL
    yum install -y python3 python3-pip
    PYTHON_CMD="python3"
  else
    echo "❌ Unsupported package manager. Please install Python manually."
    exit 1
  fi
  
  if command_exists $PYTHON_CMD; then
    echo "✅ Python installed successfully."
  else
    echo "❌ Failed to install Python. Please install it manually."
    exit 1
  fi
fi

# Check Python version
PYTHON_VERSION=$($PYTHON_CMD -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYTHON_MAJOR_VERSION=$($PYTHON_CMD -c 'import sys; print(sys.version_info.major)')
PYTHON_MINOR_VERSION=$($PYTHON_CMD -c 'import sys; print(sys.version_info.minor)')

echo "Python version: $PYTHON_VERSION"

if [ "$PYTHON_MAJOR_VERSION" -lt 3 ] || ([ "$PYTHON_MAJOR_VERSION" -eq 3 ] && [ "$PYTHON_MINOR_VERSION" -lt 7 ]); then
  echo "❌ Python 3.7 or higher is required. Please upgrade Python."
  exit 1
fi

# Install pip if not available
if ! command_exists pip3 && ! command_exists pip; then
  echo "Installing pip..."
  if command_exists apt-get; then
    apt-get install -y python3-pip
  elif command_exists apk; then
    apk add --no-cache py3-pip
  elif command_exists yum; then
    yum install -y python3-pip
  else
    echo "❌ Unsupported package manager. Please install pip manually."
    exit 1
  fi
fi

# Determine pip command
if command_exists pip3; then
  PIP_CMD="pip3"
elif command_exists pip; then
  PIP_CMD="pip"
else
  echo "❌ Failed to find pip. Please install it manually."
  exit 1
fi

# Install Python dependencies
echo "Installing Python dependencies..."
$PIP_CMD install -U openai-whisper torch numpy ffmpeg-python

# Check if Whisper was installed correctly
if $PYTHON_CMD -c "import whisper" 2>/dev/null; then
  echo "✅ Whisper installed successfully."
else
  echo "❌ Failed to install Whisper. Please check for errors above."
  exit 1
fi

echo ""
echo "===== Installation Complete ====="
echo "The audio language detector plugin dependencies have been installed."
echo ""
echo "To use the plugin:"
echo "1. Copy Tdarr_Plugin_audio_language_detector.js to your Tdarr plugins directory"
echo "2. Restart Tdarr or refresh the plugins list"
echo "3. Add the plugin to your workflow"
echo ""
echo "For more information, see the README.md file."