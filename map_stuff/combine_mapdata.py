import json
import os
from PIL import Image
import ast

LAYERS = {
    'city': ('city_colors.json', 'city_colors.png', None),
    'claims': ('claims.json', 'claims.png', []),
    'ethnicity': ('ethnicities.json', 'ethnicities.png', None),
    'gdp': ('gdp_data.json', 'gdp_data.png', 0),
    'population': ('population_color_map.json', 'population_color_map.png', 0)
}

DIRECTORIES = {
    'output': 'full_map_data.json'
}

def parse_color_key(key_string):
    try:
        # ast.literal_eval is safer than eval()
        return ast.literal_eval(key_string)
    except:
        return None

def load_data_layer(json_filename):
    """
    Loads a JSON file and converts keys from strings "(R,G,B)" to tuples (R,G,B).
    """
    path = json_filename
    if not os.path.exists(path):
        print(f"Warning: {json_filename} not found. Skipping.")
        return {}
    
    with open(path, 'r', encoding='utf-8') as f:
        raw_data = json.load(f)
    
    # Convert keys to tuples for easy matching with Image data
    processed_data = {}
    for k, v in raw_data.items():
        color_tuple = parse_color_key(k)
        if color_tuple:
            processed_data[color_tuple] = v
            
    return processed_data

def get_pixel_color(image, x, y):
    """
    Gets the RGB color at x,y. Ignores Alpha channel if present.
    """
    try:
        pixel = image.getpixel((x, y))
        # If image is RGBA, take only first 3 values
        if len(pixel) > 3:
            return pixel[:3]
        return pixel
    except IndexError:
        return (0, 0, 0)

def main():
    print("--- Starting Map Processor ---")
    
    # 1. Load the Master Region Map
    region_map_path = 'regions.png'
    if not os.path.exists(region_map_path):
        print("Error: maps/regions.png not found!")
        return

    print(f"Scanning Master Map: {region_map_path}...")
    regions_img = Image.open(region_map_path).convert('RGB')
    width, height = regions_img.size
    
    # 2. Build the Index (Color -> First X,Y Coordinate found)
    # We only need one coordinate per region color to sample the other maps.
    region_coords = {}
    
    # Optimization: Loading pixels into a 2D array is faster than getpixel() in a loop
    pixels = regions_img.load()
    
    for x in range(width):
        for y in range(height):
            color = pixels[x, y]
            # If we haven't seen this region color yet, save its coordinate
            if color not in region_coords:
                region_coords[color] = (x, y)
    
    print(f"Found {len(region_coords)} unique regions.")

    # 3. Initialize the Master Dictionary
    combined_data = {}
    for color in region_coords:
        # Convert tuple key back to string format "(R, G, B)" for the final JSON
        color_key = str(color) 
        combined_data[color_key] = {}

    # 4. Process Each Data Layer
    for key, (json_file, png_file, default_val) in LAYERS.items():
        print(f"Processing layer: {key}...")
        
        # Load the JSON data lookup for this layer
        layer_data_lookup = load_data_layer(json_file)
        
        # Load the Image for this layer
        img_path = png_file
        if not os.path.exists(img_path):
            print(f"  Warning: {png_file} not found. Using defaults.")
            layer_img = None
        else:
            layer_img = Image.open(img_path).convert('RGB')
            # Check dimensions
            if layer_img.size != regions_img.size:
                print(f"  Warning: Dimension mismatch for {png_file}. Alignment may be wrong.")

        # Apply data to every region in our master list
        for region_color_tuple, coords in region_coords.items():
            region_key_str = str(region_color_tuple)
            x, y = coords
            
            value = default_val
            
            if layer_img:
                # Get the color on the attribute map at the region's position
                attr_color = get_pixel_color(layer_img, x, y)
                
                # Check if this color exists in the loaded JSON data
                if attr_color in layer_data_lookup:
                    value = layer_data_lookup[attr_color]
            
            # Assign to master dict
            combined_data[region_key_str][key] = value

    # 5. Save Result
    print("Writing output file...")
    with open(DIRECTORIES['output'], 'w', encoding='utf-8') as f:
        json.dump(combined_data, f, indent=4)
        
    print(f"Done! Saved to {DIRECTORIES['output']}")

if __name__ == "__main__":
    main()
