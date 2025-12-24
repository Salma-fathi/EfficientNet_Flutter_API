# SmartChecker - Architecture & Data Flow

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    SMARTCHECKER SYSTEM                          │
└─────────────────────────────────────────────────────────────────┘

┌────────────────────────────┐          ┌──────────────────────────┐
│  Flutter Frontend (Mobile) │          │   FastAPI Backend        │
│                            │          │    (Python)              │
│  ┌──────────────────────┐  │  HTTP   │  ┌────────────────────┐  │
│  │  Image Picker       │  │◄────────┤◄─┤  CORS Middleware   │  │
│  │  (Gallery/Camera)   │  │  POST   │  │                    │  │
│  └──────────────────────┘  │  /predict  │  ┌────────────────┐│  │
│           ↓                │◄────────┤◄─┤  FastAPI Routes  ││  │
│  ┌──────────────────────┐  │ JSON    │  │  GET  /          ││  │
│  │  Image Upload       │  │ Response│  │  POST /predict   ││  │
│  │  with Timeout       │  │         │  │                  ││  │
│  └──────────────────────┘  │         │  └────────────────┘│  │
│           ↓                │         │         ↓            │  │
│  ┌──────────────────────┐  │         │  ┌────────────────┐  │  │
│  │  Results Display    │  │         │  │ Image Validation│  │  │
│  │  - Confidence      │  │         │  │ - File Type    │  │  │
│  │  - Probabilities   │  │         │  │ - File Size    │  │  │
│  └──────────────────────┘  │         │  └────────────────┘  │  │
│                            │         │         ↓            │  │
│  ┌──────────────────────┐  │         │  ┌────────────────┐  │  │
│  │  Error Handling     │  │         │  │ Image Processing│  │  │
│  │  - Timeout         │  │         │  │ - Resize       │  │  │
│  │  - Network         │  │         │  │ - Normalize    │  │  │
│  │  - File Type      │  │         │  │ - Padding      │  │  │
│  └──────────────────────┘  │         │  └────────────────┘  │  │
└────────────────────────────┘         │         ↓            │  │
                                       │  ┌────────────────┐  │  │
                                       │  │   PyTorch     │  │  │
                                       │  │  EfficientNet │  │  │
                                       │  │   V2-S Model  │  │  │
                                       │  └────────────────┘  │  │
                                       │         ↓            │  │
                                       │  ┌────────────────┐  │  │
                                       │  │  Classification│  │  │
                                       │  │  - Logits     │  │  │
                                       │  │  - Probabilities│ │  │
                                       │  │  - Prediction │  │  │
                                       │  └────────────────┘  │  │
                                       │         ↓            │  │
                                       │  ┌────────────────┐  │  │
                                       │  │  Response      │  │  │
                                       │  │  Formatting    │  │  │
                                       │  │  & Logging     │  │  │
                                       │  └────────────────┘  │  │
                                       └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Data Flow Sequence

```
┌──────────┐
│  User    │
└────┬─────┘
     │
     │ 1. Select Image from Gallery
     ↓
┌───────────────────────────┐
│ Flutter Image Picker      │
│ (Gallery/Camera)          │
└────┬──────────────────────┘
     │
     │ 2. Image bytes loaded
     ↓
┌───────────────────────────┐
│ Image Preparation         │
│ - Convert to bytes        │
│ - Verify file type        │
└────┬──────────────────────┘
     │
     │ 3. User taps "Run Analysis"
     ↓
┌───────────────────────────┐
│ Create HTTP Request       │
│ - Method: POST            │
│ - Endpoint: /predict      │
│ - Body: multipart/form    │
│ - Timeout: 30 seconds     │
└────┬──────────────────────┘
     │
     │ 4. Send to Backend
     ↓
   ╔════════════════════════════════════╗
   ║     NETWORK COMMUNICATION          ║
   ║  ← HTTP POST /predict              ║
   ║  → 200 OK + JSON response          ║
   ╚════════════════────════════════════╝
     │
     │ 5. Backend receives request
     ↓
┌──────────────────────────────┐
│ FastAPI Request Handler      │
│ - Extract image bytes        │
│ - Validate CORS              │
│ - Log request                │
└────┬─────────────────────────┘
     │
     │ 6. Validate image
     ↓
┌──────────────────────────────┐
│ Image Validation             │
│ - Check file type            │
│ - Verify file size (< 10MB)  │
│ - Attempt to open as image   │
└────┬─────────────────────────┘
     │
     │ 7. Preprocess image
     ↓
┌──────────────────────────────┐
│ Image Preprocessing          │
│ - Convert to RGB             │
│ - Resize & Pad to 384x384    │
│ - Normalize values           │
│ - Convert to tensor          │
└────┬─────────────────────────┘
     │
     │ 8. Load model (if not cached)
     ↓
┌──────────────────────────────┐
│ Model Loading                │
│ - Load checkpoint file       │
│ - Create EfficientNet V2-S   │
│ - Set to eval mode           │
│ - Move to device (CPU)       │
└────┬─────────────────────────┘
     │
     │ 9. Run inference
     ↓
┌──────────────────────────────┐
│ Model Inference              │
│ - Forward pass               │
│ - Get logits                 │
│ - Calculate softmax          │
│ - Get probabilities          │
│ - Argmax for prediction      │
└────┬─────────────────────────┘
     │
     │ 10. Format response
     ↓
┌──────────────────────────────┐
│ Response Formatting          │
│ - predicted_label (Real/Fake)│
│ - predicted_index (0/1)      │
│ - probabilities (dict)       │
│ - success flag               │
└────┬─────────────────────────┘
     │
     │ 11. Log and return
     ↓
┌──────────────────────────────┐
│ FastAPI Response             │
│ - JSON content               │
│ - Status: 200 OK             │
│ - Log result                 │
└────┬─────────────────────────┘
     │
     │ 12. Send to Flutter
     ↓
   ╔════════════════════════════════════╗
   ║     NETWORK COMMUNICATION          ║
   ║  ← HTTP 200 + JSON response        ║
   ╚════════════════════════════════════╝
     │
     │ 13. Flutter receives response
     ↓
┌──────────────────────────────┐
│ Response Processing          │
│ - Parse JSON                 │
│ - Check for errors           │
│ - Extract probabilities      │
└────┬─────────────────────────┘
     │
     │ 14. Display results
     ↓
┌──────────────────────────────┐
│ Results Display              │
│ - Prediction label           │
│ - Confidence percentage      │
│ - Color-coded badges         │
│ - Fade animation             │
└────┬─────────────────────────┘
     │
     │ ✓ Complete
     ↓
┌──────────┐
│  User    │
│ Sees     │
│ Results  │
└──────────┘
```

---

## Error Handling Flow

```
┌─────────────────────────────────────────────┐
│        ERROR HANDLING HIERARCHY             │
└─────────────────────────────────────────────┘

Frontend Errors:
    │
    ├─► No Image Selected
    │   └─► Message: "Please select an image first"
    │
    ├─► Network Error (Connection Failed)
    │   └─► Message: "Network Error: Failed to connect to API"
    │   └─► Suggestion: Check API URL and running status
    │
    ├─► Timeout Error
    │   └─► Message: "Timeout Error: Request took too long"
    │   └─► Duration: 30 seconds
    │
    └─► API Error Response
        └─► Status 400: Invalid file type/request
        └─► Status 413: File too large
        └─► Status 503: Model not loaded
        └─► Other: Show API detail message

Backend Errors:
    │
    ├─► File Validation
    │   ├─► Invalid extension
    │   │   └─► Response: {"error": "Invalid file type...", "error_code": "INVALID_FILE"}
    │   ├─► File too large
    │   │   └─► Response: {"detail": "File size exceeds maximum..."}
    │   └─► Cannot read file
    │       └─► Response: {"error": "Could not read image file..."}
    │
    ├─► Image Processing
    │   ├─► Cannot open image
    │   │   └─► Response: {"error": "Invalid image file...", "error_code": "INVALID_IMAGE"}
    │   └─► Preprocessing failure
    │       └─► Response: {"error": "Image preprocessing failed...", "error_code": "PREPROCESSING_ERROR"}
    │
    ├─► Model Inference
    │   ├─► Model not loaded
    │   │   └─► HTTP 503: "Model is not loaded or initialized"
    │   ├─► Inference failure
    │   │   └─► Response: {"error": "Model inference failed...", "error_code": "INFERENCE_ERROR"}
    │   └─► Probability calculation failure
    │       └─► Response: {"error": "Probability calculation failed...", "error_code": "PROBABILITY_ERROR"}
    │
    └─► Unexpected Error
        └─► Response: {"error": "Unexpected error...", "error_code": "UNEXPECTED_ERROR"}
        └─► Full stack trace in logs
```

---

## Configuration Management

```
┌────────────────────────────────────────────┐
│        Configuration Hierarchy             │
└────────────────────────────────────────────┘

1. Default Values (in code)
   ├─ MODEL_PATH = "effv2s_fold5.pt"
   ├─ API_HOST = "0.0.0.0"
   ├─ API_PORT = "8000"
   ├─ LOG_LEVEL = "INFO"
   ├─ MAX_FILE_SIZE = 10 * 1024 * 1024 (10MB)
   └─ REQUEST_TIMEOUT = 30 seconds

2. Environment Variables (override defaults)
   ├─ Read from .env file
   ├─ Set via OS environment
   └─ Used in code via os.getenv()

3. .env File (for manual configuration)
   ├─ Located in backend/ directory
   ├─ Copy from .env.example
   └─ Edit to customize for deployment
```

---

## Deployment Scenarios

### Scenario 1: Local Development

```
Frontend: Flutter run (localhost)
Backend:  uvicorn main:app --port 8000
API URL:  http://localhost:8000
```

### Scenario 2: Android Emulator

```
Frontend: Flutter run (Android Emulator)
Backend:  uvicorn main:app (on host machine)
API URL:  http://10.0.2.2:8000
```

### Scenario 3: Physical Device

```
Frontend: Flutter app on phone
Backend:  uvicorn main:app (on machine IP: 192.168.1.5)
API URL:  http://192.168.1.5:8000
```

### Scenario 4: Cloud Server

```
Frontend: Flutter app anywhere
Backend:  uvicorn main:app (on cloud server: api.example.com)
API URL:  http://api.example.com:8000
```

### Scenario 5: Docker Container

```
Frontend: Flutter app anywhere
Backend:  docker run smartchecker-api
API URL:  http://docker-host:8000
```

---

## Technology Stack

```
Frontend (Flutter)
├─ Dart Programming Language
├─ Flutter Framework (UI)
├─ image_picker (Image selection)
├─ http (Network requests)
├─ path_provider (File handling)
└─ google_fonts (Typography)

Backend (Python)
├─ Python 3.8+
├─ FastAPI (Web framework)
├─ Uvicorn (ASGI server)
├─ PyTorch (Deep learning)
├─ torchvision (Computer vision)
├─ Pillow (Image processing)
└─ python-dotenv (Configuration)

ML Model
├─ EfficientNetV2-S (Architecture)
├─ PyTorch Checkpoint (.pt file)
├─ 384x384 Input Resolution
├─ 2-class Classification (Real/Fake)
└─ CPU Inference Optimized
```

---

## Security Considerations

```
Frontend Security
├─ HTTPS enforced (in production)
├─ Certificate validation
├─ No sensitive data in logs
└─ Timeout protection

Backend Security
├─ CORS configured (specific origins in production)
├─ File type validation (prevent injection)
├─ File size limits (prevent DoS)
├─ Input validation
├─ Error message sanitization
├─ No stack traces to user
├─ Logging without sensitive data
└─ Consider adding:
   ├─ Rate limiting
   ├─ API key authentication
   ├─ HTTPS/TLS
   └─ Request signing
```

---

## Monitoring & Logging

```
Logs Generated:
│
├─ Backend Logs (when API runs)
│  ├─ Configuration loaded
│  ├─ Model initialization
│  ├─ Health check requests
│  ├─ File uploads received
│  ├─ Inference results
│  └─ Errors with full context
│
└─ Flutter Logs
   ├─ API requests
   ├─ Response parsing
   ├─ Error messages
   └─ User actions

Monitoring Points:
├─ Health Check endpoint (GET /)
├─ Prediction success rate
├─ Average inference time
├─ Error rate by type
├─ Model loading time
└─ API uptime
```

---

## Performance Metrics

```
Typical Latencies:
├─ Model Load: 2-5 seconds (once at startup)
├─ Image Upload: 1-10 seconds (depends on image size)
├─ Preprocessing: 100-500 milliseconds
├─ Inference: 500-2000 milliseconds
├─ Response Return: <100 milliseconds
└─ Total Request: 2-15 seconds

Optimization Opportunities:
├─ Image compression before upload
├─ Model quantization for faster inference
├─ GPU acceleration (if available)
├─ Batch processing
└─ Caching for identical images
```

---

For more details, see:

- [SETUP_GUIDE.md](SETUP_GUIDE.md) - Detailed setup
- [QUICKSTART.md](QUICKSTART.md) - Fast reference
- [IMPROVEMENTS.md](IMPROVEMENTS.md) - All changes made
