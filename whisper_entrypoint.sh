#!/bin/bash

LOG_FILE="/data/whisper.log"

# Function to log both to console and file
log() {
    echo "$(date +"%Y-%m-%d %H:%M:%S") - $1" >> "$LOG_FILE"
}

# Redirect all output to log file
exec >> "$LOG_FILE" 2>&1

log "Starting whisper_entrypoint.sh..."

# Default value for file path
FILE_PATH=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--file)
            FILE_PATH="$2"
            shift 2
            ;;
        *)
            log "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$FILE_PATH" ]]; then
    log "No file provided."
    exit 1
fi

FILENAME=$(basename "$FILE_PATH")

log "Processing file: $FILENAME"

# Convert to WAV
if [ ! -f "/data/input.wav" ]; then
    log "Converting $FILENAME to WAV..."
    ffmpeg -i "$FILE_PATH" -ar 16000 -ac 1 /data/input.wav
else
    log "File already converted: /data/input.wav"
fi

# Run Whisper
if [ ! -f "/data/output.vtt" ]; then
    log "Running Whisper on input.wav..."
    /app/build/bin/whisper-cli -m /models/ggml-base.bin -f /data/input.wav -ovtt -of /data/output
else
    log "File already processed: /data/output.vtt"
fi

# Bake captions
if [ ! -f "/data/output-baked.mp4" ]; then
    log "Baking subtitles into video..."
    ffmpeg -i "$FILE_PATH" -vf "subtitles=/data/output.vtt" /data/output-baked.mp4
else
    log "File already baked: /data/output-baked.mp4"
fi

# Upload the final video
if [ ! -f "/data/output-uploaded" ]; then
    log "Uploading output file..."
    curl -X POST -F "file=@/data/output-baked.mp4" "https://n8n.888ltd.ca/webhook-test/0e335121-8934-41a6-8c3c-92facb96b6c4?input=$(basename "$FILENAME")"
    touch /data/output-uploaded
else
    log "File already uploaded."
fi

# Cleanup
if [ -f "/data/output-uploaded" ]; then
    log "Processing complete. Cleaning up..."
    rm /data/*.* 2>/dev/null
    rm /data/output-uploaded
else
    log "Processing failed!"
fi
