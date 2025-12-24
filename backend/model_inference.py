import torch
import torch.nn as nn
from torchvision.models import efficientnet_v2_s
from torchvision import transforms
from PIL import Image, ImageOps
from typing import Dict, Union
from io import BytesIO
import logging

logger = logging.getLogger(__name__)

# --------------------------
# Configuration
# --------------------------
# Map class names to the model's output index
CLASS2IDX = {"Fake": 0, "Real": 1}
# Map the model's output index back to a class name
IDX2CLASS = {v: k for k, v in CLASS2IDX.items()}
IMG_SIZE = 384  # Based on the notebook's default setting

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
                 device: str = "cpu",  # Force CPU for sandbox environment
                 img_size: int = IMG_SIZE):
        """
        Initializes the predictor.
        """
        self.device = torch.device(device)
        self.img_size = img_size
        self.transform = get_inference_transform(self.img_size)
        
        # Load the single model
        logger.info(f"Loading model from {ckpt_path} onto {self.device}...")
        self.model = self._load_model(ckpt_path)
        logger.info("Model loaded successfully.")

    def _load_model(self, ckpt_path: str) -> nn.Module:
        """Private helper to load the model from its checkpoint."""
        import os
        from pathlib import Path
        
        num_classes = len(CLASS2IDX)
        
        try:
            # Check if ckpt_path is a directory (TorchScript SavedModule format)
            if os.path.isdir(ckpt_path):
                logger.info(f"Loading from SavedModule format: {ckpt_path}")
                # Try loading as TorchScript SavedModule first
                try:
                    model = torch.jit.load(ckpt_path, map_location=self.device)
                    logger.info(f"Loaded as TorchScript SavedModule")
                except Exception as e:
                    logger.warning(f"Could not load as SavedModule: {e}")
                    # Fallback: try loading data.pkl as state dict
                    data_pkl_path = os.path.join(ckpt_path, "data.pkl")
                    if os.path.exists(data_pkl_path):
                        logger.info(f"Fallback: Loading from data.pkl")
                        # Use pickle directly to handle persistent IDs
                        import pickle
                        with open(data_pkl_path, 'rb') as f:
                            sd = pickle.load(f)
                        # Check if it's wrapped in a dict with "model" key
                        if isinstance(sd, dict) and "model" in sd:
                            sd = sd["model"]
                        model = create_model(num_classes)
                        model.load_state_dict(sd)
                    else:
                        raise FileNotFoundError(f"data.pkl not found in {ckpt_path}")
            else:
                # Load from single .pt/.pth file
                logger.info(f"Loading from file format: {ckpt_path}")
                sd = torch.load(ckpt_path, map_location=self.device, weights_only=False)
                # Check if it's wrapped in a dict with "model" key
                if isinstance(sd, dict) and "model" in sd:
                    sd = sd["model"]
                model = create_model(num_classes)
                model.load_state_dict(sd)
            
            model.to(self.device)
            model.eval()  # Set model to evaluation mode
            return model
        except Exception as e:
            logger.error(f"Error loading checkpoint {ckpt_path}: {e}")
            raise

    @torch.no_grad()
    def predict(self, image_bytes: bytes) -> Dict[str, Union[str, int, float]]:
        """
        Runs inference on a single image from image bytes (received from FastAPI).
        Returns a dictionary with predicted_label, predicted_index, and probabilities.
        """
        try:
            # 1. Open image from bytes
            try:
                img = Image.open(BytesIO(image_bytes)).convert("RGB")
                logger.debug(f"Image opened successfully. Size: {img.size}")
            except Exception as e:
                logger.error(f"Error opening image from bytes: {e}")
                return {
                    "error": f"Invalid image file: {str(e)}",
                    "error_code": "INVALID_IMAGE"
                }

            # 2. Preprocess the image
            try:
                tensor = self.transform(img).unsqueeze(0).to(self.device)
                logger.debug(f"Image preprocessed. Tensor shape: {tensor.shape}")
            except Exception as e:
                logger.error(f"Error preprocessing image: {e}")
                return {
                    "error": f"Image preprocessing failed: {str(e)}",
                    "error_code": "PREPROCESSING_ERROR"
                }
            
            # 3. Run inference
            try:
                logits = self.model(tensor)
                logger.debug(f"Inference completed. Logits shape: {logits.shape}")
            except Exception as e:
                logger.error(f"Error during model inference: {e}")
                return {
                    "error": f"Model inference failed: {str(e)}",
                    "error_code": "INFERENCE_ERROR"
                }

            # 4. Calculate probabilities
            try:
                probs = torch.softmax(logits, dim=1)
                prob_fake = probs[0, CLASS2IDX["Fake"]].item()
                prob_real = probs[0, CLASS2IDX["Real"]].item()
                
                # Validate probabilities
                if not (0 <= prob_fake <= 1 and 0 <= prob_real <= 1):
                    logger.error(f"Invalid probabilities: Fake={prob_fake}, Real={prob_real}")
                    return {
                        "error": "Invalid probability values detected",
                        "error_code": "INVALID_PROBABILITY"
                    }
                logger.debug(f"Probabilities calculated - Fake: {prob_fake:.4f}, Real: {prob_real:.4f}")
            except Exception as e:
                logger.error(f"Error calculating probabilities: {e}")
                return {
                    "error": f"Probability calculation failed: {str(e)}",
                    "error_code": "PROBABILITY_ERROR"
                }
            
            # 5. Determine final prediction
            try:
                pred_idx = torch.argmax(probs, dim=1).item()
                pred_label = IDX2CLASS[pred_idx]
                logger.info(f"Prediction made: {pred_label} (index: {pred_idx})")
            except Exception as e:
                logger.error(f"Error determining prediction: {e}")
                return {
                    "error": f"Prediction determination failed: {str(e)}",
                    "error_code": "PREDICTION_ERROR"
                }
            
            # 6. Format the output
            return {
                "predicted_label": pred_label,
                "predicted_index": pred_idx,
                "probabilities": {
                    "Fake": round(prob_fake, 4),
                    "Real": round(prob_real, 4)
                },
                "success": True
            }
        except Exception as e:
            logger.error(f"Unexpected error in predict method: {e}", exc_info=True)
            return {
                "error": f"Unexpected error: {str(e)}",
                "error_code": "UNEXPECTED_ERROR"
            }

# Global variable to hold the initialized predictor
predictor = None

def initialize_predictor(ckpt_path: str):
    global predictor
    if predictor is None:
        try:
            # Note: We are forcing device="cpu" as the sandbox may not have a GPU
            logger.info("Initializing predictor...")
            predictor = ImagePredictor(ckpt_path=ckpt_path, device="cpu", img_size=IMG_SIZE)
            logger.info("Predictor initialized successfully")
        except Exception as e:
            logger.error(f"Failed to initialize predictor: {e}")
            # Re-raise the exception to stop the application startup
            raise
    return predictor
