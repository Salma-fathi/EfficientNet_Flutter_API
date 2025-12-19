from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from contextlib import asynccontextmanager
import uvicorn
import os
from model_inference import initialize_predictor, ImagePredictor

# --- Configuration ---
# Allow overriding the model path via environment variable
MODEL_PATH = os.getenv("MODEL_PATH", "effv2s_fold5.pt")

# --- Application Lifespan (Startup/Shutdown) ---
@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Handles startup and shutdown events.
    The model is loaded only once at startup.
    """
    print("Application startup: Initializing model predictor...")
    try:
        # Initialize the global predictor instance only if the model file exists
        if os.path.exists(MODEL_PATH):
            app.state.predictor = initialize_predictor(MODEL_PATH)
            print("Model predictor initialized successfully.")
        else:
            app.state.predictor = None
            print(f"WARNING: Model file not found at {MODEL_PATH}. Starting API without the model.\n"
                  "Predict endpoint will return 503 until a valid model is provided.")
    except Exception as e:
        print(f"FATAL ERROR during model initialization: {e}")
        # In a real application, you might want to gracefully handle this
        # For now, we let the startup fail.
        raise
        
    yield # Application is running
    
    # Clean up (optional, as Python handles memory)
    print("Application shutdown: Cleaning up...")
    app.state.predictor = None

# --- FastAPI App Initialization ---
app = FastAPI(
    title="EfficientNetV2-S Inference API",
    description="API for image classification using a pre-trained PyTorch EfficientNetV2-S model.",
    version="1.0.0",
    lifespan=lifespan
)

# --- Routes ---

@app.get("/")
async def root():
    """Health check endpoint."""
    status = "ok" if getattr(app.state, "predictor", None) is not None else "degraded"
    return {"message": "EfficientNetV2-S Inference API is running!", "status": status, "model_path": MODEL_PATH}

@app.post("/predict")
async def predict_image(file: UploadFile = File(...)):
    """
    Receives an image file, runs inference, and returns the prediction.
    """
    # 1. Check if the predictor is loaded
    predictor: ImagePredictor = app.state.predictor
    if predictor is None:
        raise HTTPException(status_code=503, detail="Model is not loaded or initialized.")

    # 2. Read the image file content
    try:
        image_bytes = await file.read()
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Could not read image file: {e}")

    # 3. Run inference
    try:
        # The predict method handles opening the image from bytes and running the model
        result = predictor.predict(image_bytes)
    except Exception as e:
        # Log the error for debugging purposes
        print(f"Inference error: {e}")
        raise HTTPException(status_code=500, detail=f"Internal server error during inference: {e}")

    # 4. Return the result
    return JSONResponse(content=result)

# --- Uvicorn Server (for local testing) ---
# This part is typically run via 'uvicorn main:app --host 0.0.0.0 --port 8000'
# but we include it here for completeness if run as a script.
if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
