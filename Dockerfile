FROM ghcr.io/ggerganov/whisper.cpp:main

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    python3-setuptools \
    python3-wheel \
    jq \
    && rm -rf /var/lib/apt/lists/*

# install fastapi
RUN pip install fastapi uvicorn python-multipart requests



COPY whisper_entrypoint.sh /app/whisper_entrypoint.sh
COPY whisper_api.py /app/whisper_api.py

RUN chmod +x /app/whisper_entrypoint.sh

EXPOSE 5000
ENTRYPOINT ["sh", "-c", "uvicorn whisper_api:app --host 0.0.0.0 --port 5000"]