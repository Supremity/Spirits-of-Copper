import numpy as np
from PIL import Image, ImageFilter

# 1. Define the biome-to-height mapping (RGB: Height)
# Heights are scaled to 0-255 for grayscale representation
biome_map = {
    (0, 70, 0): 0.15,
    (0, 87, 78): 0.35,
    (6, 104, 6): 0.40,
    (41, 131, 132): 0.70,
    (89, 129, 89): 0.15,
    (96, 122, 34): 0.25,
    (124, 96, 134): 0.20,
    (126, 142, 158): 0.0,
    (129, 66, 41): 0.10,
    (136, 111, 51): 0.25,
    (140, 204, 189): 0.30,
    (146, 216, 71): 0.20,
    (149, 174, 210): 0.85,
    (155, 149, 14): 0.15,
    (170, 95, 61): 0.20,
    (178, 178, 178): 0.40,
    (193, 189, 62): 0.15,
    (214, 169, 114): 0.15,
    (245, 231, 89): 0.20
}

def create_heightmap(input_path, output_path):
    # Open the biome map
    img = Image.open(input_path).convert("RGB")
    data = np.array(img)
    
    # Create an empty array for the heightmap (float for precision)
    height_array = np.zeros((data.shape[0], data.shape[1]), dtype=np.float32)

    print("Mapping colors to heights...")
    # Loop through the defined map and apply heights to the array
    for rgb, height in biome_map.items():
        # Find pixels matching this specific RGB color
        mask = np.all(data == rgb, axis=-1)
        height_array[mask] = height * 255

    # Convert to 8-bit image
    height_img = Image.fromarray(height_array.astype(np.uint8), mode='L')

    # Apply a Blur to smooth the transitions (The "Blending" part)
    # Increase the radius for smoother, more gradual slopes
    print("Smoothing transitions...")
    smooth_heightmap = height_img.filter(ImageFilter.GaussianBlur(radius=5))

    # Save the result
    smooth_heightmap.save(output_path)
    print(f"Done! Saved to {output_path}")

if __name__ == "__main__":
    create_heightmap("biomes.png", "heightmap.png")
