import os
from PIL import Image

def optimize_flags(directory):
    for filename in os.listdir(directory):
        if filename.lower().endswith(".png"):
            filepath = os.path.join(directory, filename)
            
            with Image.open(filepath) as img:
                # Convert to RGBA first to ensure transparency is handled correctly
                img = img.convert("RGBA")
                
                print(f"Optimizing Flag: {filename}")
                
                # 1. Resize (Halve dimensions)
                new_size = (max(1, img.width // 2), max(1, img.height // 2))
                img = img.resize(new_size, resample=Image.Resampling.LANCZOS)
                
                # 2. Quantize to 256 colors (Indexed mode)
                # This is perfect for flags and keeps the file tiny
                img = img.convert("P", palette=Image.ADAPTIVE, colors=256)
                
                # 3. Overwrite
                img.save(filepath, "PNG", optimize=True)

if __name__ == "__main__":
    # Ensure you are in the folder with the flags or change "." to the path
    optimize_flags("flags")
    print("\nOptimization Complete!")
