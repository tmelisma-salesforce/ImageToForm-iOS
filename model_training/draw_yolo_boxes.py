import os
import argparse
import yaml
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
from tqdm import tqdm
import sys

def yolo_to_pixels(yolo_coords, img_width, img_height):
    """
    Converts YOLO normalized coordinates (center_x, center_y, width, height)
    to pixel coordinates (xmin, ymin, xmax, ymax).

    Args:
        yolo_coords (tuple): (x_center, y_center, width, height) normalized 0-1.
        img_width (int): Width of the image in pixels.
        img_height (int): Height of the image in pixels.

    Returns:
        tuple: (xmin, ymin, xmax, ymax) in pixel coordinates, or None if invalid.
    """
    x_center, y_center, width, height = yolo_coords

    # Denormalize
    box_width = width * img_width
    box_height = height * img_height
    center_x_pixel = x_center * img_width
    center_y_pixel = y_center * img_height

    # Calculate corners
    xmin = int(center_x_pixel - (box_width / 2))
    ymin = int(center_y_pixel - (box_height / 2))
    xmax = int(center_x_pixel + (box_width / 2))
    ymax = int(center_y_pixel + (box_height / 2))

    # Clamp coordinates to image boundaries
    xmin = max(0, xmin)
    ymin = max(0, ymin)
    xmax = min(img_width, xmax)
    ymax = min(img_height, ymax)

    # Ensure valid box after clamping
    if xmin >= xmax or ymin >= ymax:
        # print(f"Warning: Invalid pixel box after conversion/clamping: ({xmin},{ymin})-({xmax},{ymax})")
        return None

    return xmin, ymin, xmax, ymax

def draw_boxes_on_image(image_path, label_path, class_names, output_path):
    """
    Draws bounding boxes and labels from a YOLO label file onto an image
    and saves the result.

    Args:
        image_path (Path): Path to the source image file.
        label_path (Path): Path to the corresponding YOLO label file (.txt).
        class_names (list): List of class names, indexed by class ID.
        output_path (Path): Path where the visualized image should be saved.

    Returns:
        bool: True if successful, False otherwise.
    """
    try:
        # Load image
        image = Image.open(image_path).convert("RGB")
        draw = ImageDraw.Draw(image)
        img_width, img_height = image.size

        # Try to load a font
        try:
            # Use a common default font if available, adjust size as needed
            font_size = max(15, int(min(img_width, img_height) * 0.02)) # Dynamic font size
            font = ImageFont.truetype("arial.ttf", font_size)
        except IOError:
            # Fallback to default PIL font if arial isn't found
            print("Warning: Arial font not found. Using default PIL font.")
            font = ImageFont.load_default()


        # Check if label file exists and is not empty
        if not label_path.exists() or label_path.stat().st_size == 0:
            # Save a copy of the original image even if no labels exist
            image.save(output_path)
            # print(f"Info: No labels found for {image_path.name}. Saved original image to output.")
            return True # Considered successful as the image is copied

        # Read label file
        with open(label_path, 'r') as f:
            lines = f.readlines()

        for line in lines:
            parts = line.strip().split()
            if len(parts) != 5:
                print(f"Warning: Skipping invalid line in {label_path.name}: '{line.strip()}'")
                continue

            try:
                class_id = int(parts[0])
                x_center = float(parts[1])
                y_center = float(parts[2])
                width = float(parts[3])
                height = float(parts[4])
            except ValueError:
                print(f"Warning: Skipping line with non-numeric values in {label_path.name}: '{line.strip()}'")
                continue

            # Validate normalized coordinates are within [0, 1]
            if not (0 <= x_center <= 1 and 0 <= y_center <= 1 and 0 <= width <= 1 and 0 <= height <= 1):
                 print(f"Warning: Skipping line with out-of-bounds normalized coordinates in {label_path.name}: '{line.strip()}'")
                 continue

            # Convert to pixel coordinates
            pixel_box = yolo_to_pixels((x_center, y_center, width, height), img_width, img_height)

            if pixel_box:
                xmin, ymin, xmax, ymax = pixel_box

                # Get class name
                if 0 <= class_id < len(class_names):
                    label_name = class_names[class_id]
                else:
                    label_name = f"ID:{class_id}" # Fallback if ID is out of range
                    print(f"Warning: Class ID {class_id} out of range in {label_path.name}. Max ID is {len(class_names)-1}.")


                # Draw rectangle
                draw.rectangle([xmin, ymin, xmax, ymax], outline="red", width=max(3, int(min(img_width, img_height) * 0.005))) # Dynamic width

                # Draw label text
                text_position = (xmin + 2, ymin + 2) # Position text slightly inside the box top-left
                # Simple background for text visibility
                text_bbox = draw.textbbox(text_position, label_name, font=font)
                draw.rectangle(text_bbox, fill="red")
                draw.text(text_position, label_name, fill="white", font=font)

        # Save the modified image
        image.save(output_path)
        return True

    except FileNotFoundError:
        print(f"Error: Image file not found: {image_path}")
        return False
    except Exception as e:
        print(f"Error processing image {image_path.name}: {e}")
        return False

def main(yolo_dataset_dir, output_dir):
    """
    Generates images with bounding boxes drawn based on a YOLO dataset.
    """
    dataset_path = Path(yolo_dataset_dir)
    output_path = Path(output_dir)
    data_yaml_path = dataset_path / "data.yaml"

    # --- 1. Validate Input and Load Config ---
    if not dataset_path.is_dir():
        print(f"Error: YOLO dataset directory not found: {dataset_path}")
        sys.exit(1)
    if not data_yaml_path.exists():
        print(f"Error: data.yaml not found in {dataset_path}")
        sys.exit(1)

    try:
        with open(data_yaml_path, 'r') as f:
            data_config = yaml.safe_load(f)
        class_names = data_config.get('names', [])
        if not class_names:
            print("Error: Could not read class names from data.yaml")
            sys.exit(1)
        print(f"Loaded {len(class_names)} classes: {class_names}")
    except Exception as e:
        print(f"Error reading data.yaml: {e}")
        sys.exit(1)

    # --- 2. Iterate Through Splits (train, val, test) ---
    splits = ['train', 'val', 'test']
    total_processed = 0
    total_skipped = 0
    total_errors = 0

    for split in splits:
        print(f"\nProcessing split: {split}")
        image_dir = dataset_path / data_config.get(split, f'images/{split}') # Use path from yaml or default structure
        label_dir = dataset_path / 'labels' / split # Labels are usually structured this way
        output_split_dir = output_path / split

        # Create output directory for the split
        output_split_dir.mkdir(parents=True, exist_ok=True)

        if not image_dir.is_dir():
            print(f"Warning: Image directory not found for split '{split}': {image_dir}. Skipping split.")
            continue
        if not label_dir.is_dir():
             print(f"Warning: Label directory not found for split '{split}': {label_dir}. Skipping split.")
             continue

        image_files = [p for p in image_dir.iterdir() if p.is_file() and p.suffix.lower() in ['.jpg', '.jpeg', '.png']]

        if not image_files:
            print(f"No images found in {image_dir}")
            continue

        # Process images within the split
        for image_path in tqdm(image_files, desc=f"Visualizing {split}"):
            label_filename = image_path.stem + ".txt"
            label_path = label_dir / label_filename
            output_image_path = output_split_dir / image_path.name

            # Idempotency check
            if output_image_path.exists():
                total_skipped += 1
                continue

            # Draw boxes and save
            success = draw_boxes_on_image(image_path, label_path, class_names, output_image_path)
            if success:
                total_processed += 1
            else:
                total_errors += 1

    print("\n--- Visualization Summary ---")
    print(f"Images processed and saved: {total_processed}")
    print(f"Images skipped (already exist): {total_skipped}")
    print(f"Errors encountered: {total_errors}")
    print(f"Visualized images saved to: {output_path.resolve()}")
    print("----------------------------")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Draw bounding boxes from a YOLO dataset onto images.")
    parser.add_argument(
        '--dataset-dir',
        type=str,
        required=True,
        help='Path to the root directory of the YOLO dataset (containing data.yaml, images/, labels/).'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        required=True,
        help='Directory where the visualized images will be saved.'
    )
    args = parser.parse_args()

    main(args.dataset_dir, args.output_dir)
