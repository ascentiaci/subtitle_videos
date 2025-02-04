FROM ghcr.io/ggerganov/whisper.cpp:main

COPY script.sh /app/script.sh

RUN chmod +x /app/script.sh

ENTRYPOINT ["/app/script.sh"]