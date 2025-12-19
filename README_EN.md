# EfficientNetV2-S Model Integration with Flutter via FastAPI

This project provides a complete solution for integrating your PyTorch/EfficientNetV2-S image classification model with a Flutter mobile application using a **FastAPI** backend in Python.

## Project Contents

The project consists of two main parts:

1.  **FastAPI Backend (Server):** Receives images, performs inference, and returns the result.
2.  **Flutter Frontend (Client):** A mobile application that allows the user to select an image and send it to the server.

---

## 1. FastAPI Backend (Python)

### Requirements

The following libraries must be installed in your Python environment:

\`\`\`bash
pip install torch torchvision fastapi uvicorn python-multipart pillow
\`\`\`

### Code Files

| File | Description |
| :--- | :--- |
| \`effv2s_fold5.pt\` | **Your model checkpoint file.** Must be placed in the same directory as the Python files. |
| \`model_inference.py\` | Contains the logic for model loading, model architecture definition (\`create_model\`), image transformation (\`ResizePadToSquare\` and \`get_inference_transform\`), and running the inference (\`ImagePredictor\`). |
| \`main.py\` | Contains the FastAPI application. It loads the model once on startup and includes the \`/predict\` endpoint that receives the image. |

### How to Run

1.  **Ensure** that your model file \`effv2s_fold5.pt\` is in the same directory as \`main.py\` and \`model_inference.py\`.
2.  Start the server using \`uvicorn\`:

    \`\`\`bash
    uvicorn main:app --host 0.0.0.0 --port 8000
    \`\`\`

3.  The API will be accessible at \`http://0.0.0.0:8000\`.

### API Endpoints

| Path | Method | Description |
| :--- | :--- | :--- |
| \`/predict\` | POST | The main endpoint. Receives an image file (\`multipart/form-data\`) and returns the classification result as JSON. |
| \`/\` | GET | Server health check. |

#### Example \`/predict\` Response (JSON)

\`\`\`json
{
  "predicted_label": "Real",
  "predicted_index": 1,
  "probabilities": {
    "Fake": 0.05,
    "Real": 0.95
  }
}
\`\`\`

---

## 2. Flutter Frontend (Client)

### Requirements

1.  A ready-to-run Flutter project.
2.  Add the required dependencies to your \`pubspec.yaml\` file:

    \`\`\`yaml
    dependencies:
      image_picker: ^1.1.2
      http: ^1.2.1
    \`\`\`

    Then run \`flutter pub get\`.

### Code Files

| File | Description |
| :--- | :--- |
| \`flutter_app/pubspec.yaml\` | Dependency definition file. |
| \`flutter_app/lib/main.dart\` | Contains the UI and the logic for selecting an image and sending it to the API via \`http.MultipartRequest\`. |

### Important Note on API Connection

In the \`main.dart\` file, the API base URL is set as follows:

\`\`\`dart
const String apiBaseUrl = 'http://10.0.2.2:8000'; 
\`\`\`

*   **If you are using an Android Emulator:** You must use \`10.0.2.2\` to access \`localhost\` on your host machine.
*   **If you are using an iOS Simulator or a physical device:** Use \`http://localhost:8000\` or the local IP address of your host machine (e.g., \`http://192.168.1.5:8000\`).
*   **If you are using a cloud server:** Replace the address with the server's public IP or domain.

### Flutter Run Steps

1.  Start the FastAPI backend (Step 2 in the FastAPI section).
2.  Open the Flutter project in your IDE.
3.  Run the application on an emulator or physical device.
4.  Tap the **"Select Image from Gallery"** button to choose an image.
5.  Tap the **"Run Prediction"** button to send the image to the API and display the result.

---

## 3. Provided Code

The following files have been created for you:

*   \`main.py\`
*   \`model_inference.py\`
*   \`flutter_app/pubspec.yaml\`
*   \`flutter_app/lib/main.dart\`

You can use these files directly in your project. Good luck with your graduation project!
