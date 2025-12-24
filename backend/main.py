from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import uvicorn
import os
import logging
from dotenv import load_dotenv
from model_inference import initialize_predictor, ImagePredictor

# Load environment variables from .env file
load_dotenv()

# Configure logging
log_level = os.getenv("LOG_LEVEL", "INFO")
logging.basicConfig(
    level=getattr(logging, log_level),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# --- Configuration ---
# Allow overriding the model path via environment variable
MODEL_PATH = os.getenv("MODEL_PATH", "effv2s_fold5.pt")
API_HOST = os.getenv("API_HOST", "0.0.0.0")
API_PORT = int(os.getenv("API_PORT", "8000"))
MAX_FILE_SIZE = int(os.getenv("MAX_FILE_SIZE", 10 * 1024 * 1024))  # 10MB default
REQUEST_TIMEOUT = int(os.getenv("REQUEST_TIMEOUT", 30))

logger.info(f"Configuration loaded - Model: {MODEL_PATH}, Host: {API_HOST}:{API_PORT}")

# --- Application Lifespan (Startup/Shutdown) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Handles startup and shutdown events.
    The model is loaded only once at startup.
    """
    logger.info("Application startup: Initializing model predictor...")
    try:
        # Initialize the global predictor instance only if the model file exists
        if os.path.exists(MODEL_PATH):
            app.state.predictor = initialize_predictor(MODEL_PATH)
            logger.info("Model predictor initialized successfully.")
        else:
            app.state.predictor = None
            logger.warning(f"Model file not found at {MODEL_PATH}. Starting API without the model.\n"
                          "Predict endpoint will return 503 until a valid model is provided.")
    except Exception as e:
        logger.error(f"FATAL ERROR during model initialization: {e}")
        raise
        
    yield  # Application is running
    
    logger.info("Application shutdown: Cleaning up...")
    app.state.predictor = None

# --- FastAPI App Initialization ---
app = FastAPI(
    title="EfficientNetV2-S Inference API",
    description="API for image classification using a pre-trained PyTorch EfficientNetV2-S model.",
    version="1.0.0",
    lifespan=lifespan
)

# Add CORS middleware to allow requests from Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Routes ---

@app.get("/")
async def root():
    """Health check endpoint."""
    status = "ok" if getattr(app.state, "predictor", None) is not None else "degraded"
    logger.info(f"Health check - Status: {status}")
    return {
        "message": "EfficientNetV2-S Inference API is running!",
        "status": status,
        "model_path": MODEL_PATH,
        "version": "1.0.0"
    }

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    """
    Receives an image file, runs inference, and returns the prediction.
    """
    # 1. Validate file type
    allowed_extensions = {'jpg', 'jpeg', 'png', 'gif', 'bmp'}
    if file.filename is None or '.' not in file.filename:
        logger.warning(f"Invalid filename: {file.filename}")
        raise HTTPException(status_code=400, detail="Invalid file - no extension found")
    
    file_ext = file.filename.rsplit('.', 1)[1].lower()
    if file_ext not in allowed_extensions:
        logger.warning(f"Invalid file type: {file_ext}")
        raise HTTPException(
            status_code=400,
            detail=f"Invalid file type '{file_ext}'. Allowed types: {', '.join(allowed_extensions)}"
        )
    
    # 2. Check if the predictor is loaded
    predictor: ImagePredictor = app.state.predictor
    if predictor is None:
        logger.error("Model predictor not loaded")
        raise HTTPException(status_code=503, detail="Model is not loaded or initialized.")

    # 3. Read the image file content
    try:
        image_bytes = await file.read()
        logger.info(f"Image received: {file.filename}, size: {len(image_bytes)} bytes")
    except Exception as e:
        logger.error(f"Error reading image file: {e}")
        raise HTTPException(status_code=400, detail=f"Could not read image file: {e}")

    # 4. Validate file size (e.g., max 10MB)
    if len(image_bytes) > MAX_FILE_SIZE:
        logger.warning(f"File too large: {len(image_bytes)} bytes")
        raise HTTPException(
            status_code=413,
            detail=f"File size exceeds maximum allowed ({MAX_FILE_SIZE / (1024*1024):.1f} MB)"
        )

    # 5. Run inference
    try:
        result = predictor.predict(image_bytes)
        logger.info(f"Inference successful for {file.filename}: {result['predicted_label']}")
    except Exception as e:
        logger.error(f"Inference error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error during inference: {e}")

    # 6. Return the result
    return JSONResponse(content=result)

# --- Uvicorn Server (for local testing) ---
# This part is typically run via 'uvicorn main:app --host 0.0.0.0 --port 8000'
# but we include it here for completeness if run as a script.
if __name__ == "__main__":
    logger.info(f"Starting SmartChecker API server on {API_HOST}:{API_PORT}")
    uvicorn.run(
        app,
        host=API_HOST,
        port=API_PORT,
        log_level=log_level.lower()
    )
