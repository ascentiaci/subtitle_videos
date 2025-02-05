from fastapi import FastAPI, Form, HTTPException
import subprocess
import logging
import json
import os
import threading
import time
import requests

LOG_FILE = "/data/whisper.log"
QUEUE_FILE = "/data/queue.json"
DOWNLOAD_FOLDER = "/data/uploads/"

app = FastAPI()

# Ensure necessary directories exist
os.makedirs(DOWNLOAD_FOLDER, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s - %(levelname)s - %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler()
    ]
)

# Ensure queue file exists
if not os.path.exists(QUEUE_FILE):
    with open(QUEUE_FILE, "w") as f:
        json.dump({"queue": [], "current_job": None}, f)


def load_queue():
    with open(QUEUE_FILE, "r") as f:
        return json.load(f)


def save_queue(data):
    with open(QUEUE_FILE, "w") as f:
        json.dump(data, f, indent=4)


def download_file(url, filename):
    """ Downloads a file from the provided URL and saves it locally. """
    local_path = os.path.join(DOWNLOAD_FOLDER, filename)
    
    try:
        response = requests.get(url, stream=True)
        response.raise_for_status()

        with open(local_path, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)

        logging.info(f"File downloaded successfully: {local_path}")
        return local_path
    except requests.exceptions.RequestException as e:
        logging.error(f"File download failed: {e}")
        return None


def process_queue():
    """ Processes jobs from the queue one by one. """
    while True:
        queue_data = load_queue()
        if queue_data["queue"]:
            job = queue_data["queue"].pop(0)
            queue_data["current_job"] = job
            save_queue(queue_data)

            file_path = job["file_path"]
            logging.info(f"Starting processing for {file_path}")

            # Run whisper script on the downloaded file
            subprocess.run(["/bin/bash", "/app/whisper_entrypoint.sh", "-i", file_path])

            queue_data["current_job"] = None
            save_queue(queue_data)

        time.sleep(5)  # Check queue every 5 seconds


# Start queue processing in background
threading.Thread(target=process_queue, daemon=True).start()


@app.post("/submit-job")
async def submit_job(url: str = Form(...), filename: str = Form(...)):
    """ Accepts a file download URL and filename, downloads the file, and adds it to the queue. """
    logging.info(f"Received job: Download {url} as {filename}")

    # Download file
    local_file_path = download_file(url, filename)
    if not local_file_path:
        raise HTTPException(status_code=500, detail="File download failed")

    # Add to queue
    queue_data = load_queue()
    queue_data["queue"].append({"file_path": local_file_path})
    save_queue(queue_data)

    return {"message": "File downloaded and added to queue", "file_path": local_file_path}


@app.get("/status")
async def status():
    queue_data = load_queue()
    return queue_data


@app.delete("/delete-job")
async def delete_job(file_path: str = Form(...)):
    """ Removes a job from the queue. """
    queue_data = load_queue()
    for job in queue_data["queue"]:
        if job["file_path"] == file_path:
            queue_data["queue"].remove(job)
            save_queue(queue_data)
            return {"message": "Job deleted"}

    raise HTTPException(status_code=404, detail="Job not found")


@app.get("/logs")
async def get_logs():
    """ Returns the latest logs. """
    with open(LOG_FILE, "r") as f:
        return {"logs": f.readlines()}
