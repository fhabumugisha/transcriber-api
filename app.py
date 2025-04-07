from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from faster_whisper import WhisperModel
import os
import shutil
import tempfile
import logging
import time
import traceback

app = FastAPI(
    title="Faster-Whisper Transcription API",
    description="API for transcribing audio files using Faster-Whisper",
    version="1.0.0"
)

# Configure logging
logging.basicConfig(level=logging.INFO, 
                    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

VALID_MODELS = ["tiny", "base", "small", "medium", "large-v1", "large-v2", "large-v3"]

@app.get("/")
async def root():
    return {"status": "online", "message": "Faster-Whisper API is running"}

@app.post("/transcribe")
async def transcribe_audio(
    file: UploadFile = File(...),
    language: str = Form(None),
    model: str = Form("small")
):
    """
    Transcribe an audio file using Faster-Whisper.
    
    - **file**: Audio file to transcribe (mp3, wav, m4a, etc.)
    - **language**: Language code (fr, en, auto, etc.) - optional
    - **model**: Model size (tiny, small, medium, large) - default: small
    """
    start_time = time.time()
    logger.info(f"Received transcription request: model={model}, language={language}, file={file.filename}")
    
    if model not in VALID_MODELS:
        raise HTTPException(
            status_code=400, 
            detail=f"Invalid model. Must be one of: {', '.join(VALID_MODELS)}"
        )
    
    # Create temporary directory
    temp_dir = tempfile.mkdtemp()
    audio_path = os.path.join(temp_dir, file.filename)
    
    try:
        # Save uploaded file
        logger.info(f"Saving uploaded file to {audio_path}")
        with open(audio_path, "wb") as f:
            shutil.copyfileobj(file.file, f)
        
        file_size = os.path.getsize(audio_path)
        logger.info(f"File saved, size: {file_size} bytes")
        
        logger.info(f"Loading whisper model: {model}")
        # Load model with appropriate compute type based on model size
        compute_type = "int8"
        if model.startswith("large"):
            # For large models, we might need to use a lower precision
            compute_type = "int8_float16"
            
        # Use environment variable for download root or fallback to /app/models
        download_root = os.environ.get("WHISPER_DOWNLOAD_ROOT", "/app/models")
        logger.info(f"Using model download root: {download_root}")
        
        whisper_model = WhisperModel(model, device="cpu", compute_type=compute_type, 
                                     local_files_only=True, download_root=download_root)
        
        logger.info("Starting transcription")
        segments, info = whisper_model.transcribe(audio_path, language=language, 
                                                  beam_size=5, best_of=5)
        
        # Collect results
        segments_data = []
        transcription = ""
        
        segment_count = 0
        for segment in segments:
            segment_count += 1
            transcription += segment.text + " "
            segments_data.append({
                "id": segment.id,
                "start": segment.start,
                "end": segment.end,
                "text": segment.text
            })
            
        elapsed_time = time.time() - start_time
        logger.info(f"Transcription complete. Detected language: {info.language}, "
                    f"processed {segment_count} segments in {elapsed_time:.2f} seconds")
        
        return {
            "model": model,
            "language": info.language,
            "text": transcription.strip(),
            "segments": segments_data,
            "processing_time_seconds": elapsed_time
        }
    
    except Exception as e:
        elapsed_time = time.time() - start_time
        error_msg = str(e)
        stack_trace = traceback.format_exc()
        logger.error(f"Transcription error after {elapsed_time:.2f} seconds: {error_msg}")
        logger.error(f"Stack trace: {stack_trace}")
        
        # Return detailed error for debugging
        raise HTTPException(
            status_code=500, 
            detail={
                "error": error_msg,
                "traceback": stack_trace,
                "processing_time_seconds": elapsed_time
            }
        )
    
    finally:
        # Clean up temporary files
        try:
            shutil.rmtree(temp_dir)
            logger.info(f"Cleaned up temporary directory: {temp_dir}")
        except Exception as e:
            logger.warning(f"Failed to clean up temporary directory: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080) 