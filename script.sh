#!/bin/bash

# Check for GGML file

if [ ! -f /models/* ]; then
/bin/bash /app/models/download-ggml-model.sh base /models
fi

# Default value for URL (blank means "not set")
URL=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--url)
            URL="$2"
            # Shift past the argument's value
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Now, $URL holds the optional value if it was passed
if [[ -n "$URL" ]]; then
    cd /data
    ENCODED_URL=$(echo "$URL" | sed 's/ /%20/g')
    FILENAME=$(basename "$ENCODED_URL")
    
    if [ -f "$FILENAME" ]; then
        echo "File already downloaded: $FILENAME"
    else
        if wget --spider "$ENCODED_URL" 2>/dev/null; then
            wget --tries=5 --retry-connrefused -O "$FILENAME" "$ENCODED_URL"
        else
            echo "Invalid URL: $URL"
            exit 1
        fi
    fi
else
    echo "No URL provided."
    exit 1
fi

# Run FFmpeg to convert the input file to .wav at 16kHz for use with whisper.cpp
ffmpeg -i "$FILENAME" -ar 16000 -ac 1 /data/input.wav

# Run whisper.cpp to generate the output file
/app/build/bin/whisper-cli -m /models/ggml-base.bin -f /data/input.wav -ovtt -of /data/output