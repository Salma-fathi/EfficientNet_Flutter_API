# SmartChecker - AI-Powered Image Authenticity Detector

[![Flutter](https://img.shields.io/badge/Flutter-Frontend-02569B?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-Backend-009688?logo=fastapi)](https://fastapi.tiangolo.com)
[![PyTorch](https://img.shields.io/badge/PyTorch-ML-EE4C2C?logo=pytorch)](https://pytorch.org)
[![EfficientNet](https://img.shields.io/badge/Model-EfficientNetV2--S-orange)](https://arxiv.org/abs/2104.00298)

## 📋 Overview

**SmartChecker** is a mobile-first AI application that detects whether images are real or artificially generated/manipulated. Powered by an EfficientNetV2-S deep learning model, it provides instant, accurate predictions with confidence scores through an intuitive Flutter interface backed by a FastAPI server.

## 🎯 What Does It Do?

SmartChecker analyzes images to determine their authenticity, helping users identify:
- AI-generated images (deepfakes, synthetic media)
- Manipulated or edited photographs
- Authentic, unaltered images

Perfect for:
- Social media verification
- News and journalism fact-checking
- Digital forensics
- Content moderation
- Educational purposes

## 🏗️ Architecture

The application follows a client-server architecture with clear separation of concerns:

```
┌─────────────────────────┐         ┌──────────────────────────┐
│   Flutter Frontend      │         │   FastAPI Backend        │
│   (Mobile App)          │ ◄─────► │   (Python API)           │
│                         │  HTTP   │                          │
│  • Image Selection      │         │  • Image Validation      │
│  • Upload & Display     │         │  • Preprocessing         │
│  • Results Visualization│         │  • ML Inference          │
│  • Error Handling       │         │  • PyTorch Model         │
└─────────────────────────┘         └──────────────────────────┘
```

### Frontend (Flutter)
- **Cross-platform** mobile app (Android/iOS)
- **Image picker** for gallery and camera capture
- **Real-time results** display with confidence scores
- **Network timeout** handling and error management
- **Responsive UI** with Material Design

### Backend (FastAPI)
- **RESTful API** for image classification
- **EfficientNetV2-S** model for inference
- **Image preprocessing** (resize, normalize, padding)
- **CORS support** for cross-origin requests
- **Comprehensive logging** and error handling
- **Environment-based** configuration

### ML Model
- **Architecture**: EfficientNetV2-S (PyTorch)
- **Input**: 384x384 RGB images
- **Output**: Binary classification (Real/Fake)
- **Inference**: CPU-optimized with softmax probabilities
- **Performance**: 2-5 second prediction time

## ✨ Key Features

### 🚀 Core Functionality
- ✅ **Real-time Image Analysis** - Get predictions in seconds
- ✅ **Confidence Scores** - See probability breakdown for each class
- ✅ **Gallery & Camera Support** - Upload existing images or take new photos
- ✅ **Visual Feedback** - Color-coded results with clear indicators
- ✅ **Error Recovery** - Robust error handling with helpful messages

### 🔒 Security & Validation
- ✅ **File Type Validation** - Accepts only valid image formats
- ✅ **Size Limits** - Protects against large file uploads (10MB max)
- ✅ **Timeout Protection** - Prevents hanging on slow connections
- ✅ **CORS Configuration** - Secure cross-origin resource sharing

### 🛠️ Developer Features
- ✅ **Professional Logging** - Comprehensive logs with severity levels
- ✅ **Environment Configuration** - Flexible deployment via .env files
- ✅ **Health Check Endpoint** - Monitor API status
- ✅ **Detailed Error Codes** - Specific error identification for debugging
- ✅ **Docker Support** - Containerized deployment ready

## 📊 Technology Stack

### Frontend
| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform mobile framework |
| **Dart** | Programming language |
| **image_picker** | Image selection from gallery/camera |
| **http** | Network requests to backend API |
| **google_fonts** | Typography and styling |

### Backend
| Technology | Purpose |
|------------|---------|
| **FastAPI** | Modern web framework for Python |
| **Uvicorn** | ASGI server for production |
| **PyTorch** | Deep learning framework |
| **torchvision** | Computer vision utilities |
| **Pillow (PIL)** | Image preprocessing |
| **python-dotenv** | Environment configuration |

### ML Infrastructure
- **Model**: EfficientNetV2-S (state-of-the-art CNN)
- **Framework**: PyTorch 1.x/2.x
- **Input Resolution**: 384×384 pixels
- **Classes**: 2 (Real, Fake)
- **Deployment**: CPU inference optimized

## 🚀 Quick Start

### Prerequisites
- **Flutter SDK** (3.0+)
- **Python** (3.8+)
- **PyTorch** and dependencies
- **Model file**: `effv2s_fold5.pt`

### Backend Setup
```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

### Frontend Setup
```bash
cd frontend
flutter pub get
# Update API URL in lib/main.dart for your platform
flutter run
```

📖 **For detailed instructions**, see [QUICKSTART.md](../QUICKSTART.md)

## 📐 Data Flow

1. **User Action**: Selects image from gallery or camera
2. **Frontend**: Prepares image and sends POST request to `/predict`
3. **Backend**: Validates image type and size
4. **Preprocessing**: Resizes to 384x384, normalizes, converts to tensor
5. **Inference**: EfficientNetV2-S model predicts Real/Fake
6. **Response**: JSON with prediction, confidence, and probabilities
7. **Display**: Results shown with color-coded badges and percentages

## 🎯 API Endpoints

### `GET /`
Health check endpoint
- **Response**: `{"message": "API is running", "model_loaded": true}`

### `POST /predict`
Image classification endpoint
- **Input**: Multipart form-data with image file
- **Output**: JSON with prediction results

**Example Response:**
```json
{
  "success": true,
  "predicted_label": "Real",
  "predicted_index": 0,
  "probabilities": {
    "Real": 0.8542,
    "Fake": 0.1458
  }
}
```

## 🛡️ Error Handling

SmartChecker includes comprehensive error handling:

| Error Type | Code | Description |
|------------|------|-------------|
| **INVALID_FILE** | 400 | Wrong file type or extension |
| **FILE_TOO_LARGE** | 413 | File exceeds 10MB limit |
| **INVALID_IMAGE** | 400 | Cannot parse as valid image |
| **PREPROCESSING_ERROR** | 500 | Image processing failed |
| **INFERENCE_ERROR** | 500 | Model prediction failed |
| **MODEL_NOT_LOADED** | 503 | ML model unavailable |

## 📱 Deployment Scenarios

### 1. Local Development
```bash
Frontend: Flutter run (localhost)
Backend:  uvicorn main:app --port 8000
API URL:  http://localhost:8000
```

### 2. Android Emulator
```bash
Frontend: Flutter run (Android Emulator)
Backend:  uvicorn main:app (host machine)
API URL:  http://10.0.2.2:8000
```

### 3. Physical Device
```bash
Frontend: Flutter app on phone
Backend:  uvicorn main:app (machine IP)
API URL:  http://192.168.1.x:8000
```

### 4. Docker Container
```bash
docker build -t smartchecker-api ./backend
docker run -p 8000:8000 smartchecker-api
```

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](../QUICKSTART.md) | Get started in 5 minutes |
| [SETUP_GUIDE.md](../SETUP_GUIDE.md) | Complete setup and troubleshooting |
| [ARCHITECTURE.md](../ARCHITECTURE.md) | Detailed architecture and data flow |
| [IMPROVEMENTS.md](../IMPROVEMENTS.md) | Changelog and enhancements |
| [.env.example](../backend/.env.example) | Configuration template |

## 🎨 Screenshots

<p align="center">
  <img src="../screenshots/home.png" width="250" alt="Home Screen"/>
  <img src="../screenshots/results.png" width="250" alt="Results Display"/>
  <img src="../screenshots/error.png" width="250" alt="Error Handling"/>
</p>

## 📈 Performance Metrics

| Metric | Typical Value |
|--------|---------------|
| Model Load Time | 2-5 seconds (startup) |
| Image Upload | 1-10 seconds (varies by size) |
| Preprocessing | 100-500 ms |
| Inference | 500-2000 ms |
| Total Request | 2-15 seconds |

## 🔐 Security Considerations

- ✅ HTTPS enforced in production
- ✅ CORS configured for specific origins
- ✅ File type and size validation
- ✅ Input sanitization
- ✅ Error message sanitization (no stack traces to users)
- ✅ Request timeout protection

**Recommended additions for production:**
- Rate limiting
- API key authentication
- Request signing
- TLS/SSL certificates

## 🧪 Testing

### Backend Tests
```bash
# Test API health
curl http://localhost:8000

# Test prediction with image
curl -X POST "http://localhost:8000/predict" -F "file=@test_image.jpg"

# Test invalid file type
curl -X POST "http://localhost:8000/predict" -F "file=@document.pdf"
```

### Frontend Tests
1. Select image from gallery
2. Test with slow network (throttle connection)
3. Test timeout scenarios
4. Verify error messages display correctly
5. Test with various image sizes and formats

## 🤝 Contributing

Contributions are welcome! Areas for improvement:
- Image compression before upload
- Batch processing for multiple images
- Prediction history database
- Web dashboard for monitoring
- GPU acceleration support
- Model quantization for faster inference

## 📄 License

This project is provided as-is for educational and research purposes.

## 🙏 Acknowledgments

- **EfficientNetV2** architecture by Google Research
- **Flutter** framework by Google
- **FastAPI** by Sebastián Ramírez
- **PyTorch** by Meta AI

## 📞 Support

For questions, issues, or setup help:
1. Check [QUICKSTART.md](../QUICKSTART.md) for common issues
2. Review [SETUP_GUIDE.md](../SETUP_GUIDE.md) troubleshooting section
3. See [ARCHITECTURE.md](../ARCHITECTURE.md) for technical details

---

**Built with ❤️ using Flutter, FastAPI, and PyTorch**

*SmartChecker - Detect. Verify. Trust.*
