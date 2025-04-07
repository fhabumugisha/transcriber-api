FROM python:3.10-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV PYTHONDONTWRITEBYTECODE=1

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Pre-download models with retry mechanism
RUN pip install --no-cache-dir requests tqdm tenacity

# Download models with retry mechanism
COPY <<EOF /app/download_models.py
import os
import sys
from tenacity import retry, stop_after_attempt, wait_exponential
from faster_whisper import WhisperModel
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("model_downloader")

@retry(wait=wait_exponential(multiplier=1, min=4, max=60), stop=stop_after_attempt(5))
def download_model(model_name, compute_type="int8"):
    logger.info(f"Downloading model {model_name} (compute_type={compute_type})...")
    try:
        model = WhisperModel(model_name, device="cpu", download_root='/app/models', 
                           compute_type=compute_type, local_files_only=False)
        logger.info(f"Successfully downloaded model {model_name}")
        return True
    except Exception as e:
        logger.error(f"Error downloading model {model_name}: {e}")
        raise

def main():
    models = [
        ("tiny", "int8"),
        ("small", "int8"), 
        ("medium", "int8")
    ]
    
    # Add large-v3 model if explicitly requested
    if len(sys.argv) > 1 and sys.argv[1] == "with-large":
        models.append(("large-v3", "int8_float16"))
    
    success = True
    for model_name, compute_type in models:
        try:
            download_model(model_name, compute_type)
        except Exception as e:
            logger.error(f"Failed to download {model_name} after multiple attempts: {e}")
            if model_name in ["tiny", "small"]:  # Essential models
                success = False
            
    return 0 if success else 1

if __name__ == "__main__":
    sys.exit(main())
EOF

# Run the model downloader script - exit code 1 if essential models fail
RUN python /app/download_models.py

# Optionally try to download large model but don't fail the build if it fails
RUN python /app/download_models.py with-large || echo "Large model download failed, but build will continue"

# Set environment variable to use local models
ENV HF_HUB_DISABLE_SYMLINKS=1
ENV WHISPER_DOWNLOAD_ROOT=/app/models

# Health check with increased timeout
HEALTHCHECK --interval=30s --timeout=60s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Expose port
EXPOSE 8080

# Run with higher timeouts and single worker for stability
CMD ["gunicorn", "app:app", "--workers", "1", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8080", "--timeout", "1800", "--keep-alive", "240", "--log-level", "debug"] 