import torch
import torch.nn as nn
from torchvision.models import efficientnet_v2_s
from torchvision import transforms
from PIL import Image, ImageOps
from typing import Dict, Union
from io import BytesIO

# --------------------------
# Configuration
# --------------------------
# Map class names to the model's output index
CLASS2IDX = {"Fake": 0, "Real": 1}
# Map the model's output index back to a class name
IDX2CLASS = {v: k for k, v in CLASS2IDX.items()}
IMG_SIZE = 384 # Based on the notebook's default setting

# --------------------------
# Model Definition
# --------------------------
def create_model(num_classes: int = 2) -> nn.Module:
    """
    Creates an EfficientNet-V2 Small model with a custom classifier head.
    """
    model = efficientnet_v2_s()
    in_features = model.classifier[-1].in_features
    model.classifier[-1] = nn.Linear(in_features, num_classes)
    return model

# --------------------------
# Preprocessing (Transform)
# --------------------------
class ResizePadToSquare:
    """
    A custom transform to resize an image to a square, preserving aspect ratio
    by scaling the longer side to `size` and padding the shorter side.
    """
    def __init__(self, size: int, fill: int = 0, interpolation = Image.Resampling.BICUBIC):
        self.size = size
        self.fill = fill
        self.interpolation = interpolation

    def __call__(self, img: Image.Image) -> Image.Image:
        if img.mode != "RGB":
            img = img.convert("RGB")
            
        w, h = img.size
        scale = self.size / max(w, h)
        new_w, new_h = max(1, int(round(w * scale))), max(1, int(round(h * scale)))
        img = img.resize((new_w, new_h), self.interpolation)
        
        pad_w = self.size - new_w
        pad_h = self.size - new_h
        left = pad_w // 2
        top = pad_h // 2
        right = pad_w - left
        bottom = pad_h - top
        
        img = ImageOps.expand(img, border=(left, top, right, bottom), fill=self.fill)
        return img

def get_inference_transform(img_size: int) -> transforms.Compose:
    """
    Returns the complete preprocessing pipeline for inference.
    """
    return transforms.Compose([
        ResizePadToSquare(img_size, fill=0, interpolation=Image.Resampling.BICUBIC),
        transforms.ToTensor(),
        transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
    ])

# --------------------------
# Inference Class (Modified for FastAPI)
# --------------------------

class ImagePredictor:
    """
    A class to load a single model and run inference on images.
    Modified to accept image bytes instead of a file path.
    """
    def __init__(self, 
                 ckpt_path: str, 
                 device: str = "cpu", # Force CPU for sandbox environment
                 img_size: int = IMG_SIZE):
        """
        Initializes the predictor.
        """
        self.device = torch.device(device)
        self.img_size = img_size
        self.transform = get_inference_transform(self.img_size)
        
        # Load the single model
        print(f"Loading model from {ckpt_path} onto {self.device}...")
        self.model = self._load_model(ckpt_path)
        print("Model loaded successfully.")

    def _load_model(self, ckpt_path: str) -> nn.Module:
        """Private helper to load the model from its checkpoint."""
        num_classes = len(CLASS2IDX)
        
        model = create_model(num_classes)
        try:
            # Load state dict from the checkpoint file
            # Assumes checkpoint is saved as {"model": state_dict, ...}
            sd = torch.load(ckpt_path, map_location=self.device)["model"]
            model.load_state_dict(sd)
            model.to(self.device)
            model.eval()  # Set model to evaluation mode
            return model
        except Exception as e:
            print(f"Error loading checkpoint {ckpt_path}: {e}")
            raise

    @torch.no_grad()
    def predict(self, image_bytes: bytes) -> Dict[str, Union[str, int, float]]:
        """
        Runs inference on a single image from image bytes (received from FastAPI).
        """
        try:
            # 1. Open image from bytes
            img = Image.open(BytesIO(image_bytes)).convert("RGB")
        except Exception as e:
            return {"error": f"Error opening image from bytes: {e}"}

        # 2. Preprocess the image
        tensor = self.transform(img).unsqueeze(0).to(self.device)
        
        # 3. Run inference
        # Note: torch.cuda.amp.autocast is removed as we are forcing CPU
        logits = self.model(tensor)
        # Calculate probabilities
        probs = torch.softmax(logits, dim=1)
        
        # 4. Get probabilities for each class
        prob_fake = probs[0, CLASS2IDX["Fake"]].item()
        prob_real = probs[0, CLASS2IDX["Real"]].item()
        
        # 5. Determine final prediction
        pred_idx = torch.argmax(probs, dim=1).item()
        pred_label = IDX2CLASS[pred_idx]
        
        # 6. Format the output
        return {
            "predicted_label": pred_label,
            "predicted_index": pred_idx,
            "probabilities": {
                "Fake": prob_fake,
                "Real": prob_real
            }
        }

# Global variable to hold the initialized predictor
predictor = None

def initialize_predictor(ckpt_path: str):
    global predictor
    if predictor is None:
        try:
            # Note: We are forcing device="cpu" as the sandbox may not have a GPU
            predictor = ImagePredictor(ckpt_path=ckpt_path, device="cpu", img_size=IMG_SIZE)
        except Exception as e:
            print(f"Failed to initialize predictor: {e}")
            # Re-raise the exception to stop the application startup
            raise
    return predictor
