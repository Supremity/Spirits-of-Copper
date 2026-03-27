from PIL import Image
import numpy as np
import os

input_folder = "./"
output_folder = "./resized_textures"
os.makedirs(output_folder, exist_ok=True)

TARGET_SIZE = (512, 512)

def trim_black(img):
    """Trim black borders from an image."""
    arr = np.array(img)

    if arr.ndim == 3 and arr.shape[2] in [3, 4]:
        mask = ~(np.all(arr[:, :, :3] == 0, axis=2))
    else:
        mask = arr != 0

    coords = np.argwhere(mask)
    if coords.size == 0:
        return img  # fully black, nothing to crop

    y0, x0 = coords.min(axis=0)
    y1, x1 = coords.max(axis=0) + 1
    return img.crop((x0, y0, x1, y1))

for file in os.listdir(input_folder):
    if not file.lower().endswith(('.png', '.jpg', '.jpeg')):
        continue

    path = os.path.join(input_folder, file)
    img = Image.open(path).convert("RGBA")  # convert all to RGBA

    # Trim black borders
    img = trim_black(img)

    # Resize to target
    img = img.resize(TARGET_SIZE, Image.LANCZOS)

    # Save as PNG
    base_name = os.path.splitext(file)[0] + ".png"
    save_path = os.path.join(output_folder, base_name)
    img.save(save_path, "PNG")

    print(f"Processed {file} → {base_name}")

print("All textures resized, black removed, and saved as PNG!")
