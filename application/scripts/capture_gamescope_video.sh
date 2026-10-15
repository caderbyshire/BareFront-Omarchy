#!/usr/bin/env bash
# Capture the presented SDL/X11 window, not gamescope's PipeWire source.
# The private runtime can supply empty NV12 frames and race backend destruction
# while allocating PipeWire buffers on exit. X11 captures the visible result.
set -Eeuo pipefail

if (( $# != 10 )); then
    echo "Usage: $0 OUTPUT SOURCE_WIDTH SOURCE_HEIGHT CROP_X CROP_Y CROP_WIDTH CROP_HEIGHT OUTPUT_WIDTH OUTPUT_HEIGHT WINDOW_ID" >&2
    exit 2
fi

OUTPUT_PATH="$1"
SOURCE_WIDTH="$2"
SOURCE_HEIGHT="$3"
CROP_X="$4"
CROP_Y="$5"
CROP_WIDTH="$6"
CROP_HEIGHT="$7"
OUTPUT_WIDTH="$8"
OUTPUT_HEIGHT="$9"
WINDOW_ID="${10}"

for VALUE in "$SOURCE_WIDTH" "$SOURCE_HEIGHT" "$CROP_WIDTH" "$CROP_HEIGHT" \
             "$OUTPUT_WIDTH" "$OUTPUT_HEIGHT" "$WINDOW_ID"; do
    if [[ ! "$VALUE" =~ ^[1-9][0-9]*$ ]]; then
        echo "Invalid capture dimension or window: $VALUE" >&2
        exit 2
    fi
done
for VALUE in "$CROP_X" "$CROP_Y"; do
    if [[ ! "$VALUE" =~ ^(0|[1-9][0-9]*)$ ]]; then
        echo "Invalid capture position: $VALUE" >&2
        exit 2
    fi
done
if (( CROP_X + CROP_WIDTH > SOURCE_WIDTH || CROP_Y + CROP_HEIGHT > SOURCE_HEIGHT ||
      OUTPUT_WIDTH % 2 || OUTPUT_HEIGHT % 2 )); then
    echo "Invalid capture bounds or output dimensions." >&2
    exit 2
fi
command -v ffmpeg >/dev/null || { echo 'Capture requires ffmpeg.' >&2; exit 1; }
: "${DISPLAY:?Capture requires the gameplay X11 display}"

mkdir -p -- "$(dirname -- "$OUTPUT_PATH")"
TEMP_OUTPUT="$(mktemp "${OUTPUT_PATH}.part.XXXXXX.mp4")"
CAPTURE_PID=""
cleanup() {
    if [[ -n "$CAPTURE_PID" ]]; then
        kill -TERM "$CAPTURE_PID" 2>/dev/null || true
        wait "$CAPTURE_PID" 2>/dev/null || true
    fi
    rm -f -- "$TEMP_OUTPUT"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# Crop in the actual window's coordinates. Do this before converting to
# yuv420p, whose chroma alignment would otherwise round odd crop positions.
FILTER="format=rgb24,crop=${CROP_WIDTH}:${CROP_HEIGHT}:${CROP_X}:${CROP_Y}"
FILTER+=",scale=${OUTPUT_WIDTH}:${OUTPUT_HEIGHT}:flags=lanczos,setsar=1"
ffmpeg -nostdin -hide_banner -loglevel error -y \
    -f x11grab -window_id "$WINDOW_ID" -framerate 30 \
    -video_size "${SOURCE_WIDTH}x${SOURCE_HEIGHT}" -draw_mouse 0 \
    -i "$DISPLAY" -t 5 -an -vf "$FILTER" \
    -c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p \
    "$TEMP_OUTPUT" &
CAPTURE_PID=$!
STATUS=0
wait "$CAPTURE_PID" || STATUS=$?
CAPTURE_PID=""
if (( STATUS != 0 )) || [[ ! -s "$TEMP_OUTPUT" ]]; then
    echo "Gamescope window recording failed: $STATUS" >&2
    exit 1
fi
mv -f -- "$TEMP_OUTPUT" "$OUTPUT_PATH"
echo "Video saved: $OUTPUT_PATH"
