#!/bin/bash

# DASH Adaptive Bitrate Video Encoding Script
# Usage: ./encode_dash.sh input.mp4 output_name
# Run this script in your target directory (e.g., /var/www/videos/dash/)

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_video> <output_name>"
    echo "Example: $0 example.mp4 my_video"
    exit 1
fi

INPUT_VIDEO="$1"
VIDEO_NAME="$2"

if [ ! -f "${INPUT_VIDEO}" ]; then
    echo "Error: Input file '${INPUT_VIDEO}' not found!"
    exit 1
fi

# Create output directory in current location
mkdir -p "${VIDEO_NAME}"

echo "=========================================="
echo "Starting DASH Encoding"
echo "Input: ${INPUT_VIDEO}"
echo "Output: ./${VIDEO_NAME}/"
echo "=========================================="

###########################################
# DASH ENCODING (VP9/WebM)
###########################################
echo ""
echo "Encoding DASH video streams..."

# Encode video tracks
ffmpeg -i "${INPUT_VIDEO}" \
  -c:v libvpx-vp9 -keyint_min 150 -g 150 -tile-columns 4 -frame-parallel 1 -speed 4 -threads 8 \
  -an -vf scale=640:360 -b:v 800k -f webm -dash 1 "${VIDEO_NAME}/video_360p_800k.webm" \
  -an -vf scale=854:480 -b:v 1400k -f webm -dash 1 "${VIDEO_NAME}/video_480p_1400k.webm" \
  -an -vf scale=1280:720 -b:v 2800k -f webm -dash 1 "${VIDEO_NAME}/video_720p_2800k.webm" \
  -an -vf scale=1920:1080 -b:v 5000k -f webm -dash 1 "${VIDEO_NAME}/video_1080p_5000k.webm"

echo ""
echo "Encoding DASH audio stream..."

# Encode audio track
ffmpeg -i "${INPUT_VIDEO}" -c:a libopus -b:a 128k -vn -f webm -dash 1 "${VIDEO_NAME}/audio_128k.webm"

echo ""
echo "Creating DASH manifest..."

# Create DASH manifest
ffmpeg \
  -f webm_dash_manifest -i "${VIDEO_NAME}/video_360p_800k.webm" \
  -f webm_dash_manifest -i "${VIDEO_NAME}/video_480p_1400k.webm" \
  -f webm_dash_manifest -i "${VIDEO_NAME}/video_720p_2800k.webm" \
  -f webm_dash_manifest -i "${VIDEO_NAME}/video_1080p_5000k.webm" \
  -f webm_dash_manifest -i "${VIDEO_NAME}/audio_128k.webm" \
  -c copy \
  -map 0 -map 1 -map 2 -map 3 -map 4 \
  -f webm_dash_manifest \
  -adaptation_sets "id=0,streams=0,1,2,3 id=1,streams=4" \
  "${VIDEO_NAME}/manifest.mpd"

echo "✓ DASH encoding complete!"

echo ""
echo "=========================================="
echo "Encoding Complete!"
echo "=========================================="
echo ""
echo "Output directory: ./${VIDEO_NAME}/"
echo ""
echo "Manifest file: ${VIDEO_NAME}/manifest.mpd"
echo ""
echo "Quality levels available:"
echo "  - 1080p (5000 kbps) - ${VIDEO_NAME}/video_1080p_5000k.webm"
echo "  - 720p  (2800 kbps) - ${VIDEO_NAME}/video_720p_2800k.webm"
echo "  - 480p  (1400 kbps) - ${VIDEO_NAME}/video_480p_1400k.webm"
echo "  - 360p  (800 kbps)  - ${VIDEO_NAME}/video_360p_800k.webm"
echo "  - Audio (128 kbps)  - ${VIDEO_NAME}/audio_128k.webm"
echo ""
echo "=========================================="