#!/bin/bash

# Combined HLS + DASH Video Encoding Script with 4K Support
# Usage: ./encode_video.sh input.mp4 output_name
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
echo "DUAL ENCODING: HLS + DASH (with 4K)"
echo "=========================================="
echo "Input: ${INPUT_ABS}"
echo "Output name: ${VIDEO_NAME}"
echo "=========================================="

###########################################
# STEP 1: ENCODE HLS (H.264)
###########################################
echo ""
echo "STEP 1/2: Encoding HLS (H.264) with 4K..."
echo "=========================================="

cd hls/ || { echo "Error: hls/ directory not found!"; exit 1; }

mkdir -p "${VIDEO_NAME}/360p"
mkdir -p "${VIDEO_NAME}/480p"
mkdir -p "${VIDEO_NAME}/720p"
mkdir -p "${VIDEO_NAME}/1080p"
mkdir -p "${VIDEO_NAME}/2160p"

ffmpeg -i "${INPUT_ABS}" \
  -filter_complex \
  "[0:v]split=5[v1][v2][v3][v4][v5]; \
   [v1]scale=w=640:h=360[v360p]; \
   [v2]scale=w=854:h=480[v480p]; \
   [v3]scale=w=1280:h=720[v720p]; \
   [v4]scale=w=1920:h=1080[v1080p]; \
   [v5]scale=w=3840:h=2160[v2160p]" \
  \
  -map "[v360p]" -c:v:0 libx264 -b:v:0 800k -maxrate:v:0 856k -bufsize:v:0 1200k -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:0 baseline -preset veryfast \
  -map 0:a -c:a:0 aac -b:a:0 96k -ar 44100 \
  -f hls -hls_time 4 -hls_playlist_type vod -hls_segment_filename "${VIDEO_NAME}/360p/segment_%03d.ts" \
  "${VIDEO_NAME}/360p/playlist.m3u8" \
  \
  -map "[v480p]" -c:v:1 libx264 -b:v:1 1400k -maxrate:v:1 1498k -bufsize:v:1 2100k -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:1 main -preset veryfast \
  -map 0:a -c:a:1 aac -b:a:1 128k -ar 44100 \
  -f hls -hls_time 4 -hls_playlist_type vod -hls_segment_filename "${VIDEO_NAME}/480p/segment_%03d.ts" \
  "${VIDEO_NAME}/480p/playlist.m3u8" \
  \
  -map "[v720p]" -c:v:2 libx264 -b:v:2 2800k -maxrate:v:2 2996k -bufsize:v:2 4200k -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:2 main -preset veryfast \
  -map 0:a -c:a:2 aac -b:a:2 128k -ar 44100 \
  -f hls -hls_time 4 -hls_playlist_type vod -hls_segment_filename "${VIDEO_NAME}/720p/segment_%03d.ts" \
  "${VIDEO_NAME}/720p/playlist.m3u8" \
  \
  -map "[v1080p]" -c:v:3 libx264 -b:v:3 5000k -maxrate:v:3 5350k -bufsize:v:3 7500k -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:3 high -preset veryfast \
  -map 0:a -c:a:3 aac -b:a:3 192k -ar 44100 \
  -f hls -hls_time 4 -hls_playlist_type vod -hls_segment_filename "${VIDEO_NAME}/1080p/segment_%03d.ts" \
  "${VIDEO_NAME}/1080p/playlist.m3u8" \
  \
  -map "[v2160p]" -c:v:4 libx264 -b:v:4 10000k -maxrate:v:4 11000k -bufsize:v:4 15000k -g 48 -keyint_min 48 -sc_threshold 0 -profile:v:4 high -preset medium \
  -map 0:a -c:a:4 aac -b:a:4 256k -ar 48000 \
  -f hls -hls_time 4 -hls_playlist_type vod -hls_segment_filename "${VIDEO_NAME}/2160p/segment_%03d.ts" \
  "${VIDEO_NAME}/2160p/playlist.m3u8"

if [ $? -eq 0 ]; then
    # Create master playlist for HLS
    cat > "${VIDEO_NAME}/master.m3u8" << EOF
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-STREAM-INF:BANDWIDTH=896000,RESOLUTION=640x360,CODECS="avc1.42c01e,mp4a.40.2"
360p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1528000,RESOLUTION=854x480,CODECS="avc1.4d401f,mp4a.40.2"
480p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2928000,RESOLUTION=1280x720,CODECS="avc1.4d401f,mp4a.40.2"
720p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=5192000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
1080p/playlist.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=10256000,RESOLUTION=3840x2160,CODECS="avc1.640033,mp4a.40.2"
2160p/playlist.m3u8
EOF
    echo "HLS encoding complete!"
else
    echo "HLS encoding failed!"
    exit 1
fi

cd ..

###########################################
# STEP 2: ENCODE DASH (H.265)
###########################################
echo ""
echo "STEP 2/2: Encoding DASH (H.265) with 4K..."
echo "=========================================="

cd dash/ || { echo "Error: dash/ directory not found!"; exit 1; }

mkdir -p "${VIDEO_NAME}"

ffmpeg -i "${INPUT_ABS}" \
  -filter_complex \
  "[0:v]split=5[v1][v2][v3][v4][v5]; \
   [v1]scale=w=640:h=360[v360p]; \
   [v2]scale=w=854:h=480[v480p]; \
   [v3]scale=w=1280:h=720[v720p]; \
   [v4]scale=w=1920:h=1080[v1080p]; \
   [v5]scale=w=3840:h=2160[v2160p]" \
  \
  -map "[v360p]" -c:v:0 libx265 -b:v:0 600k -maxrate:v:0 660k -bufsize:v:0 1200k \
    -g 48 -keyint_min 48 -preset medium -x265-params "scenecut=0" \
  -map "[v480p]" -c:v:1 libx265 -b:v:1 1000k -maxrate:v:1 1100k -bufsize:v:1 2000k \
    -g 48 -keyint_min 48 -preset medium -x265-params "scenecut=0" \
  -map "[v720p]" -c:v:2 libx265 -b:v:2 2000k -maxrate:v:2 2200k -bufsize:v:2 4000k \
    -g 48 -keyint_min 48 -preset medium -x265-params "scenecut=0" \
  -map "[v1080p]" -c:v:3 libx265 -b:v:3 3500k -maxrate:v:3 3850k -bufsize:v:3 7000k \
    -g 48 -keyint_min 48 -preset medium -x265-params "scenecut=0" \
  -map "[v2160p]" -c:v:4 libx265 -b:v:4 8000k -maxrate:v:4 8800k -bufsize:v:4 16000k \
    -g 48 -keyint_min 48 -preset medium -x265-params "scenecut=0" \
  \
  -map 0:a -c:a aac -b:a 128k \
  \
  -f dash \
  -seg_duration 6 \
  -use_timeline 1 \
  -use_template 1 \
  -init_seg_name "init_\$RepresentationID\$.m4s" \
  -media_seg_name "segment_\$RepresentationID\$_\$Number\$.m4s" \
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
echo "ALL ENCODING COMPLETE!"
echo "=========================================="
echo ""
echo "Output Locations:"
echo ""
echo "HLS (H.264/AAC):"
echo "  Master playlist: hls/${VIDEO_NAME}/master.m3u8"
echo "  URL: http://your-server/vod/hls/${VIDEO_NAME}/master.m3u8"
echo ""
echo "DASH (H.265/AAC):"
echo "  Manifest: dash/${VIDEO_NAME}/manifest.mpd"
echo "  URL: http://your-server/vod/dash/${VIDEO_NAME}/manifest.mpd"
echo ""
echo "Quality levels: 360p, 480p, 720p, 1080p, 2160p (4K)"
echo ""
echo "=========================================="