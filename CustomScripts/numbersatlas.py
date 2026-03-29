from PIL import Image, ImageDraw, ImageFont

# --- Settings ---
OUTPUT_NAME = "numbers_atlas.png"
CANVAS_WIDTH = 1024  # Total width (100px per digit)
CANVAS_HEIGHT = 128  # Total height
FONT_SIZE = 110       # Size of the numbers
FONT_PATH = "arial.TTF" # Or any .ttf font on your system

def generate_atlas():
    # Create a transparent canvas (RGBA)
    atlas = Image.new("RGBA", (CANVAS_WIDTH, CANVAS_HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(atlas)

    try:
        # Load font
        font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    except:
        print("Font not found, using default.")
        font = ImageFont.load_default()

    # Draw digits 0-9
    for i in range(10):
        digit = str(i)
        slot_width = CANVAS_WIDTH // 10
        x_offset = i * slot_width
        bbox = draw.textbbox((0, 0), digit, font=font)
        w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
        text_x = x_offset + (slot_width - w) / 2
        text_y = (CANVAS_HEIGHT - h) / 2 - bbox[1]  # baseline adjustment
        draw.text((text_x, text_y), digit, fill=(255, 255, 255, 255), font=font)

    atlas.save(OUTPUT_NAME)
    print(f"Success! {OUTPUT_NAME} generated ({CANVAS_WIDTH}x{CANVAS_HEIGHT})")

if __name__ == "__main__":
    generate_atlas()
