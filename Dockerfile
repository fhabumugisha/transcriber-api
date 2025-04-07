FROM python:3.10-slim

WORKDIR /app

# Install system dependencies and Python packages in one layer
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    ffmpeg \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/* \
    && pip install --no-cache-dir requests tqdm

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    HF_HUB_DISABLE_SYMLINKS=1 \
    WHISPER_DOWNLOAD_ROOT=/app/models

# Copy and install requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY app.py .

# Create directory for models and download base models
RUN mkdir -p /app/models \
    && python -c "from faster_whisper import WhisperModel; \
       print('Downloading tiny model...'); \
       WhisperModel('tiny', device='cpu', download_root='/app/models'); \
       print('Downloading small model...'); \
       WhisperModel('small', device='cpu', download_root='/app/models')" \
    && echo "Basic models downloaded successfully"

# Try to download medium model but don't fail the build if it fails
RUN python -c "from faster_whisper import WhisperModel; \
    try: \
        print('Downloading medium model...'); \
        WhisperModel('medium', device='cpu', download_root='/app/models'); \
        print('Medium model downloaded successfully'); \
    except Exception as e: \
        print(f'Medium model download failed: {e}, but build will continue')" || true

# Health check
HEALTHCHECK --interval=30s --timeout=60s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8080/ || exit 1

# Expose port
EXPOSE 8080

# Run the application
CMD ["gunicorn", "app:app", "--workers", "1", "--worker-class", "uvicorn.workers.UvicornWorker", "--bind", "0.0.0.0:8080", "--timeout", "1800", "--keep-alive", "240", "--log-level", "debug"] 