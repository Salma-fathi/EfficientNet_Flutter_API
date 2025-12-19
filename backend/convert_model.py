#!/usr/bin/env python3
"""
Script to convert the SavedModule format to a standard PyTorch .pt file.
This handles PyTorch models saved with CUDA storage references.
"""
import torch
import torch.nn as nn
from torchvision.models import efficientnet_v2_s
from pathlib import Path
import pickle
import torch._utils

# Model configuration
CLASS2IDX = {"Fake": 0, "Real": 1}
IMG_SIZE = 384

def create_model(num_classes: int = 2) -> nn.Module:
    """Creates an EfficientNet-V2 Small model with a custom classifier head."""
    model = efficientnet_v2_s()
    in_features = model.classifier[-1].in_features
    model.classifier[-1] = nn.Linear(in_features, num_classes)
    return model

def convert_savedmodule_to_pt():
    """Convert the SavedModule directory to a .pt file."""
    
    savedmodule_dir = Path("effv2s_fold5")
    output_file = Path("effv2s_fold5.pt")
    
    if not savedmodule_dir.exists():
        print(f"ERROR: Directory {savedmodule_dir} not found!")
        return False
    
    try:
        print(f"Attempting to load SavedModule from {savedmodule_dir}...")
        
        data_pkl = savedmodule_dir / "data.pkl"
        if not data_pkl.exists():
            print(f"ERROR: data.pkl not found in {savedmodule_dir}!")
            return False
        
        print(f"Loading {data_pkl}...")
        
        state_dict = None
        
        # Try 1: Direct load with CPU mapping
        try:
            print("Method 1: Direct torch.load with CPU mapping...")
            state_dict = torch.load(str(data_pkl), map_location="cpu", weights_only=False)
            print("✓ Successfully loaded!")
            
        except Exception as e1:
            print(f"✗ Failed: {e1}")
            
            # Try 2: Load on CUDA then move to CPU  
            try:
                print("Method 2: Load on CUDA then move to CPU...")
                if torch.cuda.is_available():
                    state_dict = torch.load(str(data_pkl), map_location="cuda", weights_only=False)
                    # Move all tensors to CPU
                    for key in state_dict:
                        if isinstance(state_dict[key], torch.Tensor):
                            state_dict[key] = state_dict[key].cpu()
                    print("✓ Loaded on CUDA and moved to CPU")
                else:
                    raise RuntimeError("CUDA not available")
                    
            except Exception as e2:
                print(f"✗ Failed: {e2}")
                
                # Try 3: Custom pickle unpickler with tensor rebuilder
                try:
                    print("Method 3: Custom pickle unpickler with persistent_load handler...")
                    
                    # Save original rebuild function
                    original_rebuild = torch._utils._rebuild_tensor_v2
                    
                    def rebuild_tensor_cpu(*args, **kwargs):
                        """Custom tensor builder that creates CPU tensors."""
                        result = original_rebuild(*args, **kwargs)
                        if isinstance(result, torch.Tensor) and result.is_cuda:
                            result = result.cpu()
                        return result
                    
                    def persistent_load(saved_id):
                        """Handle PyTorch's persistent ID references."""
                        # The saved_id is typically a tuple like ('storage', 'FloatStorage', device, size)
                        return saved_id
                    
                    # Temporarily replace the rebuild function
                    torch._utils._rebuild_tensor_v2 = rebuild_tensor_cpu
                    
                    try:
                        with open(data_pkl, 'rb') as f:
                            unpickler = pickle.Unpickler(f)
                            unpickler.persistent_load = persistent_load
                            state_dict = unpickler.load()
                        print("✓ Loaded with custom persistent_load handler")
                    finally:
                        # Restore original function
                        torch._utils._rebuild_tensor_v2 = original_rebuild
                        
                except Exception as e3:
                    print(f"✗ Failed: {e3}")
                    import traceback
                    traceback.print_exc()
                    return False
        
        if state_dict is None:
            print("ERROR: Could not load state dict!")
            return False
        
        print(f"\n✓ Loaded state dict type: {type(state_dict)}")
        if isinstance(state_dict, dict):
            keys = list(state_dict.keys())
            print(f"  Dictionary has {len(keys)} top-level keys")
            if len(keys) <= 5:
                print(f"  Keys: {keys}")
            else:
                print(f"  First 5 keys: {keys[:5]}")
            
            # Check if it's wrapped in a "model" key
            if len(keys) == 1 and "model" in state_dict:
                print("  Found 'model' wrapper, extracting...")
                state_dict = state_dict["model"]
                print(f"  Extracted {len(state_dict)} model parameters")
        
        # Create fresh model
        print("\n✓ Creating fresh EfficientNetV2-S model...")
        model = create_model(len(CLASS2IDX))
        
        # Load state dict
        print("  Loading state dict into model...")
        try:
            model.load_state_dict(state_dict)
            print("  ✓ State dict loaded successfully!")
        except RuntimeError as e:
            print(f"  ✗ State dict mismatch: {e}")
            print("    This means the model architecture doesn't match the saved weights.")
            return False
        
        # Ensure model is on CPU
        model = model.cpu()
        model.eval()
        
        # Save as standard .pt file
        print(f"\n✓ Saving model to {output_file}...")
        checkpoint = {"model": model.state_dict()}
        torch.save(checkpoint, output_file)
        print(f"  ✓ Model saved successfully!")
        
        # Verify the saved file
        print("\n✓ Verifying saved file...")
        verify_state = torch.load(str(output_file), map_location="cpu")
        if isinstance(verify_state, dict):
            if "model" in verify_state:
                print(f"  ✓ Verification OK: 'model' key contains {len(verify_state['model'])} parameters")
            else:
                print(f"  ✓ Verification OK: {len(verify_state)} top-level keys")
        
        print("\n" + "="*60)
        print("SUCCESS: Model conversion complete!")
        print(f"Model saved to: {output_file}")
        print("="*60)
        return True
        
    except Exception as e:
        print(f"\nUnexpected error: {e}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    success = convert_savedmodule_to_pt()
    exit(0 if success else 1)


