#!/bin/bash

# Adaptive Bitrate Video Encoding Script
# Usage: ./encode_hls.sh input.mp4 output_name
# Run this script in your target directory (e.g., /var/www/videos/hls/)

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

# Create output directories in current location
mkdir -p "${VIDEO_NAME}/360p"
mkdir -p "${VIDEO_NAME}/480p"
mkdir -p "${VIDEO_NAME}/720p"
mkdir -p "${VIDEO_NAME}/1080p"

echo "=========================================="
echo "Starting HLS Encoding"
echo "Input: ${INPUT_VIDEO}"
echo "Output: ./${VIDEO_NAME}/"
echo "=========================================="

###########################################
# HLS ENCODING (H.264)
###########################################
echo ""
echo "Encoding HLS streams with adaptive bitrate..."

# Single FFmpeg command for all HLS qualities
ffmpeg -i "${INPUT_VIDEO}" \
  -filter_complex \
  "[0:v]split=4[v1][v2][v3][v4]; \
   [v1]scale=w=640:h=360[v360p]; \
   [v2]scale=w=854:h=480[v480p]; \
   [v3]scale=w=1280:h=720[v720p]; \
   [v4]scale=w=1920:h=1080[v1080p]" \
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
  "${VIDEO_NAME}/1080p/playlist.m3u8"

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
EOF

echo "✓ HLS encoding complete!"

echo ""
echo "=========================================="
echo "Encoding Complete!"
echo "=========================================="
echo ""
echo "Output directory: ./${VIDEO_NAME}/"
echo ""
echo "Master playlist: ${VIDEO_NAME}/master.m3u8"
echo ""
echo "Quality levels available:"
echo "  - 1080p (5000 kbps) - ${VIDEO_NAME}/1080p/playlist.m3u8"
echo "  - 720p  (2800 kbps) - ${VIDEO_NAME}/720p/playlist.m3u8"
echo "  - 480p  (1400 kbps) - ${VIDEO_NAME}/480p/playlist.m3u8"
echo "  - 360p  (800 kbps)  - ${VIDEO_NAME}/360p/playlist.m3u8"
echo ""
echo "=========================================="