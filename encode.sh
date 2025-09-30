#!/bin/bash

# Master Video Encoding Script - HLS + DASH
# Usage: ./encode_both.sh input.mp4 output_name
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
echo "DUAL ENCODING: HLS + DASH"
echo "=========================================="
echo "Input: ${INPUT_ABS}"
echo "Output name: ${VIDEO_NAME}"
echo "=========================================="

###########################################
# STEP 1: ENCODE HLS
###########################################
echo ""
echo "▶ STEP 1/2: Encoding HLS (H.264)..."
echo "=========================================="

cd hls/ || { echo "Error: hls/ directory not found!"; exit 1; }

ffmpeg -i "${INPUT_ABS}" \
  -filter_complex \
  "[0:v]split=4[v1][v2][v3][v4]; \
   [v1]scale=w=640:h=360[v360p]; \
   [v2]scale=w=854:h=480[v480p]; \
   [v3]scale=w=1280:h=720[v720p]; \
   [v4]scale=w=1920:h=1080[v1080p]" \
  \
  -map "[v360p]" -c:v:0 libx264 -b:v:0 800k -maxrate:v:0 880k -bufsize:v:0 1600k \
    -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:0 baseline -preset faster \
  -map 0:a -c:a:0 aac -b:a:0 96k -ar 44100 \
  \
  -map "[v480p]" -c:v:1 libx264 -b:v:1 1400k -maxrate:v:1 1540k -bufsize:v:1 2800k \
    -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:1 main -preset faster \
  -map 0:a -c:a:1 aac -b:a:1 128k -ar 44100 \
  \
  -map "[v720p]" -c:v:2 libx264 -b:v:2 2800k -maxrate:v:2 3080k -bufsize:v:2 5600k \
    -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:2 main -preset faster \
  -map 0:a -c:a:2 aac -b:a:2 128k -ar 44100 \
  \
  -map "[v1080p]" -c:v:3 libx264 -b:v:3 5000k -maxrate:v:3 5500k -bufsize:v:3 10000k \
    -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:3 high -preset faster \
  -map 0:a -c:a:3 aac -b:a:3 192k -ar 44100 \
  \
  -f hls \
  -hls_time 6 \
  -hls_playlist_type vod \
  -hls_flags independent_segments \
  -hls_segment_filename "${VIDEO_NAME}/stream_%v/segment_%03d.ts" \
  -master_pl_name master.m3u8 \
  -var_stream_map "v:0,a:0,name:360p v:1,a:1,name:480p v:2,a:2,name:720p v:3,a:3,name:1080p" \
  "${VIDEO_NAME}/stream_%v.m3u8"

if [ $? -eq 0 ]; then
    echo "✓ HLS encoding complete!"
else
    echo "✗ HLS encoding failed!"
    exit 1
fi

cd ..

###########################################
# STEP 2: ENCODE DASH
###########################################
echo ""
echo "▶ STEP 2/2: Encoding DASH (VP9)..."
echo "=========================================="

cd dash/ || { echo "Error: dash/ directory not found!"; exit 1; }

ffmpeg -i "${INPUT_ABS}" \
  -filter_complex \
  "[0:v]split=4[v1][v2][v3][v4]; \
   [v1]scale=w=640:h=360[v360p]; \
   [v2]scale=w=854:h=480[v480p]; \
   [v3]scale=w=1280:h=720[v720p]; \
   [v4]scale=w=1920:h=1080[v1080p]" \
  \
  -map "[v360p]" -c:v:0 libvpx-vp9 -b:v:0 800k -maxrate:v:0 880k -bufsize:v:0 1600k \
    -g 150 -keyint_min 150 -tile-columns 2 -frame-parallel 1 -speed 2 -threads 4 \
  -map "[v480p]" -c:v:1 libvpx-vp9 -b:v:1 1400k -maxrate:v:1 1540k -bufsize:v:1 2800k \
    -g 150 -keyint_min 150 -tile-columns 2 -frame-parallel 1 -speed 2 -threads 4 \
  -map "[v720p]" -c:v:2 libvpx-vp9 -b:v:2 2800k -maxrate:v:2 3080k -bufsize:v:2 5600k \
    -g 150 -keyint_min 150 -tile-columns 3 -frame-parallel 1 -speed 2 -threads 4 \
  -map "[v1080p]" -c:v:3 libvpx-vp9 -b:v:3 5000k -maxrate:v:3 5500k -bufsize:v:3 10000k \
    -g 150 -keyint_min 150 -tile-columns 4 -frame-parallel 1 -speed 2 -threads 4 \
  \
  -map 0:a -c:a:0 libopus -b:a:0 96k \
  -map 0:a -c:a:1 libopus -b:a:1 128k \
  \
  -f dash \
  -seg_duration 6 \
  -use_timeline 1 \
  -use_template 1 \
  -init_seg_name "${VIDEO_NAME}/init_\$RepresentationID\$.webm" \
  -media_seg_name "${VIDEO_NAME}/segment_\$RepresentationID\$_\$Number\$.webm" \
  -adaptation_sets "id=0,streams=v id=1,streams=a" \
  "${VIDEO_NAME}/manifest.mpd"

if [ $? -eq 0 ]; then
    echo "✓ DASH encoding complete!"
else
    echo "✗ DASH encoding failed!"
    exit 1
fi

cd ..

###########################################
# SUMMARY
###########################################
echo ""
echo "=========================================="
echo "✓ ALL ENCODING COMPLETE!"
echo "=========================================="
echo ""
echo "📁 Output Locations:"
echo ""
echo "HLS (H.264/AAC):"
echo "  Master playlist: hls/${VIDEO_NAME}/master.m3u8"
echo "  URL: http://your-server/vod/hls/${VIDEO_NAME}/master.m3u8"
echo ""
echo "DASH (VP9/Opus):"
echo "  Manifest: dash/${VIDEO_NAME}/manifest.mpd"
echo "  URL: http://your-server/vod/dash/${VIDEO_NAME}/manifest.mpd"
echo ""
echo "Quality levels: 360p, 480p, 720p, 1080p"
echo ""
echo "=========================================="