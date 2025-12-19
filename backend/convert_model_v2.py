#!/usr/bin/env python3
"""
Load PyTorch SavedModule format with detached storage and convert to .pt file.
The model has storage data in separate files under the 'data' directory.
"""
import torch
import torch.nn as nn
from torchvision.models import efficientnet_v2_s
from pathlib import Path
import pickle
import struct

# Model configuration
CLASS2IDX = {"Fake": 0, "Real": 1}
IMG_SIZE = 384

def create_model(num_classes: int = 2) -> nn.Module:
    """Creates an EfficientNet-V2 Small model with a custom classifier head."""
    model = efficientnet_v2_s()
    in_features = model.classifier[-1].in_features
    model.classifier[-1] = nn.Linear(in_features, num_classes)
    return model

def load_savedmodule_with_detached_storage():
    """Load SavedModule with detached storage files."""
    
    savedmodule_dir = Path("effv2s_fold5")
    data_dir = savedmodule_dir / "data"
    data_pkl = savedmodule_dir / "data.pkl"
    
    if not data_pkl.exists():
        print(f"ERROR: {data_pkl} not found!")
        return None
    
    if not data_dir.exists():
        print(f"ERROR: {data_dir} not found!")
        return None
    
    print(f"Loading SavedModule from {savedmodule_dir}...")
    print(f"  - Metadata: {data_pkl}")
    print(f"  - Storage files: {data_dir}/")
    
    # Create a mapping of storage indices to their file paths
    storage_files = {}
    for idx_file in data_dir.iterdir():
        try:
            idx = int(idx_file.name)
            storage_files[idx] = idx_file
        except ValueError:
            pass
    
    print(f"  - Found {len(storage_files)} storage files")
    
    # Custom persistent_load that loads from storage files
    def persistent_load(saved_id):
        """Load tensor storage from files."""
        # saved_id is typically: ('storage', 'FloatStorage', device, size) or similar
        if isinstance(saved_id, tuple) and len(saved_id) >= 3:
            try:
                storage_type = saved_id[1]  # e.g., 'FloatStorage', 'IntStorage'
                storage_idx = saved_id[3]  # The index into storage_files
                
                if storage_idx in storage_files:
                    storage_file = storage_files[storage_idx]
                    # Load the binary storage data
                    with open(storage_file, 'rb') as f:
                        data = f.read()
                    
                    # Create appropriate storage type
                    if 'Float' in storage_type:
                        # Convert bytes to float tensor and extract storage
                        tensor_data = torch.frombuffer(data, dtype=torch.float32)
                        return tensor_data.storage()
                    elif 'Int' in storage_type or 'Long' in storage_type:
                        tensor_data = torch.frombuffer(data, dtype=torch.int64)
                        return tensor_data.storage()
                    else:
                        print(f"Unknown storage type: {storage_type}")
                        return None
            except Exception as e:
                print(f"Error loading storage: {e}")
                return None
        return None
    
    # Load the pickle file with custom persistent_load
    try:
        print("\nLoading pickle metadata with custom storage loader...")
        with open(data_pkl, 'rb') as f:
            unpickler = pickle.Unpickler(f)
            unpickler.persistent_load = persistent_load
            state_dict = unpickler.load()
        
        print("✓ Successfully loaded state dict")
        return state_dict
        
    except Exception as e:
        print(f"✗ Failed to load: {e}")
        import traceback
        traceback.print_exc()
        return None

def convert_to_pt():
    """Convert loaded state dict to .pt file."""
    
    output_file = Path("effv2s_fold5.pt")
    
    # Load the model
    state_dict = load_savedmodule_with_detached_storage()
    if state_dict is None:
        print("ERROR: Failed to load state dict")
        return False
    
    print(f"\n✓ Loaded state dict type: {type(state_dict)}")
    if isinstance(state_dict, dict):
        keys = list(state_dict.keys())
        print(f"  - Dictionary has {len(keys)} top-level keys")
        if len(keys) <= 5:
            print(f"  - Keys: {keys}")
        else:
            print(f"  - First 5 keys: {keys[:5]}")
        
        # Check if it's wrapped in a "model" key
        if len(keys) == 1 and "model" in state_dict:
            print("  - Found 'model' wrapper, extracting...")
            state_dict = state_dict["model"]
            print(f"  - Extracted {len(state_dict)} model parameters")
    
    # Create fresh model and load state
    print("\n✓ Creating fresh EfficientNetV2-S model...")
    model = create_model(len(CLASS2IDX))
    
    print("  - Loading state dict into model...")
    try:
        model.load_state_dict(state_dict)
        print("  ✓ State dict loaded successfully!")
    except RuntimeError as e:
        print(f"  ✗ State dict mismatch: {e}")
        return False
    
    # Ensure model is on CPU and in eval mode
    model = model.cpu()
    model.eval()
    
    # Save as standard .pt file
    print(f"\n✓ Saving model to {output_file}...")
    checkpoint = {"model": model.state_dict()}
    torch.save(checkpoint, output_file)
    print(f"  ✓ Model saved successfully!")
    
    # Verify
    print("\n✓ Verifying saved file...")
    verify_state = torch.load(str(output_file), map_location="cpu")
    if isinstance(verify_state, dict) and "model" in verify_state:
        print(f"  ✓ Verification OK: Contains {len(verify_state['model'])} parameters")
    
    print("\n" + "="*60)
    print("SUCCESS: Model conversion complete!")
    print(f"Model saved to: {output_file}")
    print("="*60)
    return True

if __name__ == "__main__":
    success = convert_to_pt()
    exit(0 if success else 1)
