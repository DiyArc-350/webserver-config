#!/bin/bash

# DASH Video Encoding Script with 4K Support (VP9)
# Usage: ./encode_dash.sh input.mp4 output_name
# Run this from /var/www/videos/

if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <input_video> <output_name>"
    echo "Example: $0 source/video.mp4 my_video"
    exit 1
fi

INPUT_VIDEO="$1"
VIDEO_NAME="$2"

if [ ! -f "${INPUT_VIDEO}" ]; then
    echo "Error: Input file '${INPUT_VIDEO}' not found!"
    exit 1
fi

# Get absolute path of input video
INPUT_ABS=$(realpath "${INPUT_VIDEO}")

echo "=========================================="
echo "DASH ENCODING (VP9) with 4K"
echo "=========================================="
echo "Input: ${INPUT_ABS}"
echo "Output name: ${VIDEO_NAME}"
echo "=========================================="

###########################################
# ENCODE DASH (VP9)
###########################################
echo ""
echo "Encoding DASH (VP9) with 4K..."
echo "=========================================="

cd dash/ || { echo "Error: dash/ directory not found!"; exit 1; }

mkdir -p "${VIDEO_NAME}"

ffmpeg -y -i "${INPUT_ABS}" \
  -filter_complex \
  "[0:v]split=5[v1][v2][v3][v4][v5]; \
   [v1]scale=w=640:h=360[v360p]; \
   [v2]scale=w=854:h=480[v480p]; \
   [v3]scale=w=1280:h=720[v720p]; \
   [v4]scale=w=1920:h=1080[v1080p]; \
   [v5]scale=w=3840:h=2160[v2160p]" \
  \
  -map "[v360p]" -c:v:0 libvpx-vp9 -b:v:0 500k -maxrate:v:0 550k -bufsize:v:0 1000k \
    -g 48 -keyint_min 48 -tile-columns 0 -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
    -row-mt 1 -speed 2 -quality good \
  -map "[v480p]" -c:v:1 libvpx-vp9 -b:v:1 800k -maxrate:v:1 880k -bufsize:v:1 1600k \
    -g 48 -keyint_min 48 -tile-columns 1 -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
    -row-mt 1 -speed 2 -quality good \
  -map "[v720p]" -c:v:2 libvpx-vp9 -b:v:2 1600k -maxrate:v:2 1760k -bufsize:v:2 3200k \
    -g 48 -keyint_min 48 -tile-columns 2 -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
    -row-mt 1 -speed 2 -quality good \
  -map "[v1080p]" -c:v:3 libvpx-vp9 -b:v:3 2800k -maxrate:v:3 3080k -bufsize:v:3 5600k \
    -g 48 -keyint_min 48 -tile-columns 2 -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
    -row-mt 1 -speed 2 -quality good \
  -map "[v2160p]" -c:v:4 libvpx-vp9 -b:v:4 6000k -maxrate:v:4 6600k -bufsize:v:4 12000k \
    -g 48 -keyint_min 48 -tile-columns 3 -frame-parallel 0 -auto-alt-ref 1 -lag-in-frames 25 \
    -row-mt 1 -speed 2 -quality good \
  \
  -map 0:a -c:a libopus -b:a 128k \
  \
  -f dash \
  -seg_duration 6 \
  -use_timeline 1 \
  -use_template 1 \
  -single_file 0 \
  -write_prft 1 \
  -ldash 0 \
  -streaming 0 \
  -init_seg_name "init_\$RepresentationID\$.webm" \
  -media_seg_name "segment_\$RepresentationID\$_\$Number\$.webm" \
  -adaptation_sets "id=0,streams=v id=1,streams=a" \
  "${VIDEO_NAME}/manifest.mpd"

if [ $? -eq 0 ]; then
    echo "DASH encoding complete!"
else
    echo "DASH encoding failed!"
    exit 1
fi

cd ..

###########################################
# SUMMARY
###########################################
echo ""
echo "=========================================="
echo "DASH ENCODING COMPLETE!"
echo "=========================================="
echo ""
echo "Output Location:"
echo ""
echo "DASH (VP9/Opus):"
echo "  Manifest: dash/${VIDEO_NAME}/manifest.mpd"
echo "  URL: http://your-server/vod/dash/${VIDEO_NAME}/manifest.mpd"
echo ""
echo "Quality levels: 360p, 480p, 720p, 1080p, 2160p (4K)"
echo ""
echo "Note: VP9 encoding is slower but produces smaller files"
echo "=========================================="