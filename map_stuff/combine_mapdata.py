import json
import os
from PIL import Image
import ast

# --- CONFIGURATION ---
LAYERS = {
    'city': ('city_colors.json', 'city_colors.png', ""),
    'claims': ('claims.json', 'claims.png', []),
    # Default ethnicity is now a dict with empty values
    'ethnicity': ('ethnicities.json', 'ethnicities.png', {"name": "", "color": "(0, 0, 0)"}), 
    'gdp': ('gdp_data.json', 'gdp_data.png', 0),
    'population': ('population_color_map.json', 'population_color_map.png', 0)
}

DIRECTORIES = {
    'output': 'full_map_data.json'
}

def parse_color_key(key_string):
    try:
        return ast.literal_eval(key_string)
    except:
        return None

def load_data_layer(json_filename):
    if not os.path.exists(json_filename):
        print(f"Warning: {json_filename} not found. Skipping.")
        return {}
    
    with open(json_filename, 'r', encoding='utf-8') as f:
        raw_data = json.load(f)
    
    processed_data = {}
    for k, v in raw_data.items():
        color_tuple = parse_color_key(k)
        if color_tuple:
            processed_data[color_tuple] = v
            
    return processed_data

def get_pixel_color(image, x, y):
    try:
        pixel = image.getpixel((x, y))
        if len(pixel) > 3:
            return pixel[:3]
        return pixel
    except IndexError:
        return (0, 0, 0)

def main():
    print("--- Starting Map Processor ---")
    
    region_map_path = 'regions.png'
    if not os.path.exists(region_map_path):
        print("Error: regions.png not found!")
        return

    print(f"Scanning Master Map: {region_map_path}...")
    regions_img = Image.open(region_map_path).convert('RGB')
    width, height = regions_img.size
    
    region_coords = {}
    pixels = regions_img.load()
    
    for x in range(width):
        for y in range(height):
            color = pixels[x, y]
            if color not in region_coords:
                region_coords[color] = (x, y)
    
    print(f"Found {len(region_coords)} unique regions.")

    combined_data = {}
    for color in region_coords:
        combined_data[str(color)] = {}

    for key, (json_file, png_file, default_val) in LAYERS.items():
        print(f"Processing layer: {key}...")
        
        layer_data_lookup = load_data_layer(json_file)
        
        img_path = png_file
        if not os.path.exists(img_path):
            print(f"  Warning: {png_file} not found. Using defaults.")
            layer_img = None
        else:
            layer_img = Image.open(img_path).convert('RGB')
            if layer_img.size != regions_img.size:
                print(f"  Warning: Dimension mismatch for {png_file}.")

        for region_color_tuple, coords in region_coords.items():
            region_key_str = str(region_color_tuple)
            x, y = coords
            
            value = default_val
            
            if layer_img:
                attr_color = get_pixel_color(layer_img, x, y)
                if attr_color in layer_data_lookup:
                    # SPECIAL LOGIC FOR ETHNICITY
                    if key == 'ethnicity':
                        value = {
                            "name": layer_data_lookup[attr_color],
                            "color": str(attr_color) # The original RGB key
                        }
                    else:
                        value = layer_data_lookup[attr_color]
            
            combined_data[region_key_str][key] = value

    print("Writing output file...")
    with open(DIRECTORIES['output'], 'w', encoding='utf-8') as f:
        json.dump(combined_data, f, indent=4)
        
    print(f"Done! Saved to {DIRECTORIES['output']}")

if __name__ == "__main__":
    main()
