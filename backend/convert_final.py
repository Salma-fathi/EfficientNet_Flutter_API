#!/usr/bin/env python3
"""
Load PyTorch SavedModule with proper storage reconstruction.
The format is: ('storage', <storage_class>, storage_index_str, device_str, size)
"""
import torch
import torch.nn as nn
from torchvision.models import efficientnet_v2_s
from pathlib import Path
import pickle

# Model configuration
CLASS2IDX = {"Fake": 0, "Real": 1}

def create_model(num_classes: int = 2) -> nn.Module:
    """Creates an EfficientNet-V2 Small model with a custom classifier head."""
    model = efficientnet_v2_s()
    in_features = model.classifier[-1].in_features
    model.classifier[-1] = nn.Linear(in_features, num_classes)
    return model

def convert_to_pt():
    """Convert the SavedModule to .pt file."""
    
    savedmodule_dir = Path("effv2s_fold5")
    data_pkl = savedmodule_dir / "data.pkl"
    data_dir = savedmodule_dir / "data"
    output_file = Path("effv2s_fold5.pt")
    
    if not data_pkl.exists():
        print(f"ERROR: {data_pkl} not found!")
        return False
    
    print("Loading SavedModule with storage reconstruction...")
    
    # Load storage files into memory
    print(f"Loading storage files...")
    storage_data = {}
    for storage_file in sorted(data_dir.glob('[0-9]*')):
        try:
            idx = int(storage_file.name)
            with open(storage_file, 'rb') as f:
                storage_data[idx] = f.read()
        except (ValueError, IOError):
            pass
    
    print(f"Loaded {len(storage_data)} storage files")
    
    # Create custom persistent_load
    def persistent_load(saved_id):
        """Reconstruct storage from saved_id and storage_data."""
        # saved_id format: ('storage', <torch.StorageClass>, storage_index_str, device_str, size)
        # Example: ('storage', <class 'torch.FloatStorage'>, '0', 'cuda:0', 648)
        
        if not isinstance(saved_id, tuple) or len(saved_id) < 4:
            raise RuntimeError(f"Unexpected persistent id: {saved_id}")
        
        tag = saved_id[0]  # 'storage'
        storage_class = saved_id[1]  # torch.FloatStorage, torch.IntStorage, etc. (the class itself!)
        storage_id_str = saved_id[2]  # storage index as STRING
        device_info = saved_id[3]  # device string like 'cuda:0'
        
        if tag != 'storage':
            raise RuntimeError(f"Unknown persistent id tag: {tag}")
        
        # Convert storage index from string to int
        try:
            storage_id = int(storage_id_str)
        except (ValueError, TypeError):
            raise RuntimeError(f"Cannot convert storage_id to int: {storage_id_str} (from saved_id: {saved_id})")
        
        if storage_id not in storage_data:
            raise RuntimeError(f"Storage {storage_id} not found in storage_data (available: {sorted(storage_data.keys())[:10]}...)")
        
        raw_bytes = storage_data[storage_id]
        
        # Get dtype from storage class name
        storage_class_str = str(storage_class)
        
        if 'FloatStorage' in storage_class_str:
            dtype = torch.float32
        elif 'DoubleStorage' in storage_class_str:
            dtype = torch.float64
        elif 'HalfStorage' in storage_class_str:
            dtype = torch.float16
        elif 'IntStorage' in storage_class_str:
            dtype = torch.int32
        elif 'LongStorage' in storage_class_str:
            dtype = torch.int64
        elif 'ShortStorage' in storage_class_str:
            dtype = torch.int16
        elif 'ByteStorage' in storage_class_str or 'CharStorage' in storage_class_str:
            dtype = torch.uint8
        elif 'BoolStorage' in storage_class_str:
            dtype = torch.bool
        else:
            # Default to float32
            dtype = torch.float32
            print(f"Warning: Unknown storage class {storage_class_str}, defaulting to float32")
        
        # Create tensor from raw bytes and extract storage
        tensor_data = torch.frombuffer(raw_bytes, dtype=dtype).clone()
        storage = tensor_data.storage()
        
        return storage
    
    # Load pickle with custom persistent_load
    try:
        print("\nLoading metadata with custom persistent_load...")
        with open(data_pkl, 'rb') as f:
            unpickler = pickle.Unpickler(f)
            unpickler.persistent_load = persistent_load
            state_dict = unpickler.load()
        
        print(f"✓ Loaded state dict: {type(state_dict)}")
        
    except Exception as e:
        print(f"✗ Failed to load: {e}")
        import traceback
        traceback.print_exc()
        return False
    
    # Process state_dict
    if isinstance(state_dict, dict):
        keys = list(state_dict.keys())
        print(f"  - Dictionary has {len(keys)} top-level keys")
        if len(keys) == 1 and "model" in state_dict:
            print("  - Found 'model' wrapper, extracting...")
            state_dict = state_dict["model"]
            print(f"  - Extracted {len(state_dict)} model parameters")

        # Extract model from state_dict if wrapped
        if "model" in state_dict:
            print(f"  - Found 'model' key, extracting...")
            state_dict = state_dict["model"]
            print(f"  - Extracted {len(state_dict)} model parameters")
    
    # Create and load model
    print("\n✓ Creating fresh EfficientNetV2-S model...")
    model = create_model(len(CLASS2IDX))
    
    print("  - Loading state dict into model...")
    try:
        model.load_state_dict(state_dict)
        print("  ✓ State dict loaded successfully!")
    except RuntimeError as e:
        print(f"  ✗ Failed: {e}")
        return False
    
    # Save as .pt file
    model = model.cpu().eval()
    print(f"\n✓ Saving to {output_file}...")
    torch.save({"model": model.state_dict()}, output_file)
    print("  ✓ Saved successfully!")
    
    print("\n" + "="*60)
    print("SUCCESS: Model converted to " + str(output_file))
    print("="*60)
    return True

if __name__ == "__main__":
    success = convert_to_pt()
    exit(0 if success else 1)
