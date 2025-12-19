#!/usr/bin/env python3
"""
Load PyTorch SavedModule with proper storage reconstruction.
"""
import torch
import torch.nn as nn
from torchvision.models import efficientnet_v2_s
from pathlib import Path
import pickle
import io

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
    print(f"Loading {len(list(data_dir.glob('*')))} storage files...")
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
        # saved_id format: ('storage', StorageType, device, size)
        # or ('storage', StorageType, device_str, size)
        
        if not isinstance(saved_id, tuple) or len(saved_id) < 4:
            raise RuntimeError(f"Unexpected persistent id: {saved_id}")
        
        tag = saved_id[0]  # 'storage'
        storage_type = saved_id[1]  # 'FloatStorage', 'IntStorage', etc.
        device_info = saved_id[2]  # device string
        storage_id = saved_id[3]  # storage index
        
        if tag != 'storage':
            raise RuntimeError(f"Unknown persistent id tag: {tag}")
        
        if storage_id not in storage_data:
            raise RuntimeError(f"Storage {storage_id} not found in storage_data")
        
        raw_bytes = storage_data[storage_id]
        
        # Determine dtype from storage_type
        if 'Float' in storage_type:
            dtype = torch.float32
        elif 'Double' in storage_type:
            dtype = torch.float64
        elif 'Half' in storage_type:
            dtype = torch.float16
        elif 'Int' in storage_type:
            dtype = torch.int32
        elif 'Long' in storage_type:
            dtype = torch.int64
        elif 'Short' in storage_type:
            dtype = torch.int16
        elif 'Byte' in storage_type:
            dtype = torch.uint8
        elif 'Char' in storage_type:
            dtype = torch.int8
        elif 'Bool' in storage_type:
            dtype = torch.bool
        else:
            raise RuntimeError(f"Unknown storage type: {storage_type}")
        
        # Convert device string to torch device
        try:
            device = torch.device(device_info.replace(':0', '').replace('cuda', 'cpu'))
        except:
            device = torch.device('cpu')
        
        # Create tensor from raw bytes and extract storage
        tensor_data = torch.frombuffer(raw_bytes, dtype=dtype).clone()
        storage = tensor_data.storage()
        
        # If device is not CPU, we might need to move it, but we'll keep on CPU
        return storage
        # Create custom persistent_load
        def persistent_load(saved_id):
            """Reconstruct storage from saved_id and storage_data."""
            # saved_id format: ('storage', StorageType, storage_index_str, device_str, size) 
            # Example: ('storage', 'FloatStorage', '76', 'cuda:0', 147456)
        
            if not isinstance(saved_id, tuple) or len(saved_id) < 4:
                raise RuntimeError(f"Unexpected persistent id: {saved_id}")
        
            tag = saved_id[0]  # 'storage'
            storage_type = saved_id[1]  # 'FloatStorage', 'IntStorage', etc.
            storage_id_str = saved_id[2]  # storage index as STRING!
            device_info = saved_id[3]  # device string like 'cuda:0'
        
            if tag != 'storage':
                raise RuntimeError(f"Unknown persistent id tag: {tag}")
        
            # Convert storage index from string to int
            try:
                storage_id = int(storage_id_str)
            except (ValueError, TypeError):
                raise RuntimeError(f"Cannot convert storage_id to int: {storage_id_str}")
        
            if storage_id not in storage_data:
                raise RuntimeError(f"Storage {storage_id} not found in storage_data (available: {list(storage_data.keys())[:5]}...)")
        
            raw_bytes = storage_data[storage_id]
        
            # Determine dtype from storage_type
            if 'Float' in storage_type:
                dtype = torch.float32
            elif 'Double' in storage_type:
                dtype = torch.float64
            elif 'Half' in storage_type:
                dtype = torch.float16
            elif 'Int' in storage_type:
                dtype = torch.int32
            elif 'Long' in storage_type:
                dtype = torch.int64
            elif 'Short' in storage_type:
                dtype = torch.int16
            elif 'Byte' in storage_type:
                dtype = torch.uint8
            elif 'Char' in storage_type:
                dtype = torch.int8
            elif 'Bool' in storage_type:
                dtype = torch.bool
            else:
                raise RuntimeError(f"Unknown storage type: {storage_type}")
        
            # Get dtype from storage class
            storage_class = storage_type  # This is actually torch.FloatStorage, torch.IntStorage, etc.
        
            # Map storage classes to dtypes
            if 'FloatStorage' in str(storage_class):
                dtype = torch.float32
            elif 'DoubleStorage' in str(storage_class):
                dtype = torch.float64
            elif 'HalfStorage' in str(storage_class):
                dtype = torch.float16
            elif 'IntStorage' in str(storage_class):
                dtype = torch.int32
            elif 'LongStorage' in str(storage_class):
                dtype = torch.int64
            elif 'ShortStorage' in str(storage_class):
                dtype = torch.int16
            elif 'CharStorage' in str(storage_class) or 'ByteStorage' in str(storage_class):
                dtype = torch.uint8
            elif 'BoolStorage' in str(storage_class):
                dtype = torch.bool
            else:
                # Fallback to float32
                dtype = torch.float32
        
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
