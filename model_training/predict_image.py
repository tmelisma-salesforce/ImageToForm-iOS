import argparse
from pathlib import Path
from ultralytics import YOLO
from PIL import Image, ImageDraw, ImageFont
import sys
import yaml # To load class names from data.yaml

# Define default classes in case data.yaml is not accessible or needed
DEFAULT_CLASSES = ["flip-flops", "helmet", "glove", "boots"]

def draw_predictions(image_path, results, output_path, class_names, conf_threshold=0.25):
    """
    Draws bounding boxes and labels on an image based on YOLO results.

    Args:
        image_path (Path): Path to the original image.
        results (list): The output list from model.predict(). Should contain one Results object.
        output_path (Path): Path to save the visualized image.
        class_names (list): List of class names corresponding to model output indices.
        conf_threshold (float): Minimum confidence score to draw a box.
    """
    try:
        if not results or len(results) == 0:
            print(f"Warning: No results returned by model for {image_path.name}")
            # Optionally copy the original image if no detections
            # shutil.copy2(image_path, output_path)
            return False

        # Assuming results is a list containing one Results object
        result = results[0]
        orig_img = result.orig_img # Get the original image array used for prediction
        img_pil = Image.fromarray(orig_img[..., ::-1]) # Convert BGR (from OpenCV) to RGB for PIL
        draw = ImageDraw.Draw(img_pil)

        # Try to load a font
        try:
            font_size = max(15, int(min(img_pil.width, img_pil.height) * 0.02))
            font = ImageFont.truetype("arial.ttf", font_size)
        except IOError:
            print("Warning: Arial font not found. Using default PIL font.")
            font = ImageFont.load_default()

        boxes = result.boxes # Access the Boxes object
        if boxes is None or len(boxes) == 0:
             print(f"Info: No boxes detected in {image_path.name} above threshold.")
             # Save the original image if no boxes found
             img_pil.save(output_path)
             return True

        for box in boxes:
            conf = box.conf.item() # Confidence score
            if conf >= conf_threshold:
                xyxy = box.xyxy[0].cpu().numpy().astype(int) # Get box coordinates as numpy array
                class_id = int(box.cls.item()) # Class ID

                # Get class name
                if 0 <= class_id < len(class_names):
                    label_name = class_names[class_id]
                else:
                    label_name = f"ID:{class_id}"
                    print(f"Warning: Class ID {class_id} out of range for known names.")

                label = f"{label_name} {conf:.2f}"
                xmin, ymin, xmax, ymax = xyxy

                # Draw rectangle
                draw.rectangle([xmin, ymin, xmax, ymax], outline="red", width=max(3, int(min(img_pil.width, img_pil.height) * 0.005)))

                # Draw label text with background
                text_position = (xmin + 2, ymin + 2)
                text_bbox = draw.textbbox(text_position, label, font=font)
                # Add small padding to background rectangle
                bg_coords = (text_bbox[0]-1, text_bbox[1]-1, text_bbox[2]+1, text_bbox[3]+1)
                draw.rectangle(bg_coords, fill="red")
                draw.text(text_position, label, fill="white", font=font)

        # Save the modified image
        img_pil.save(output_path)
        print(f"Saved prediction visualization to: {output_path}")
        return True

    except Exception as e:
        print(f"Error drawing predictions for {image_path.name}: {e}")
        import traceback
        traceback.print_exc() # Print detailed traceback for debugging
        return False

def main(model_path, image_path, output_dir, conf_thresh, data_yaml_path):
    """
    Loads a YOLO model, performs prediction on an image, and saves visualization.
    """
    model_file = Path(model_path)
    img_file = Path(image_path)
    output_dir = Path(output_dir)
    data_yaml_file = Path(data_yaml_path) if data_yaml_path else None

    # --- 1. Validate Inputs ---
    if not model_file.exists():
        print(f"Error: Model file not found at {model_file}")
        sys.exit(1)
    if not img_file.exists():
        print(f"Error: Input image file not found at {img_file}")
        sys.exit(1)

    # Create output directory if it doesn't exist
    output_dir.mkdir(parents=True, exist_ok=True)

    # --- 2. Load Class Names ---
    class_names = DEFAULT_CLASSES # Start with default
    if data_yaml_file and data_yaml_file.exists():
        try:
            with open(data_yaml_file, 'r') as f:
                data_config = yaml.safe_load(f)
            loaded_names = data_config.get('names', [])
            if loaded_names:
                class_names = loaded_names
                print(f"Loaded {len(class_names)} class names from {data_yaml_file.name}")
            else:
                print(f"Warning: Could not read 'names' from {data_yaml_file.name}. Using default classes.")
        except Exception as e:
            print(f"Warning: Error reading {data_yaml_file.name}: {e}. Using default classes.")
    else:
         print("Warning: data.yaml path not provided or not found. Using default class names.")
         print(f"Default classes: {class_names}")


    # --- 3. Load Model ---
    try:
        print(f"Loading model from {model_file}...")
        # Trust the source since it's your trained model
        model = YOLO(str(model_file))
        print("Model loaded successfully.")
    except Exception as e:
        print(f"Error loading YOLO model: {e}")
        sys.exit(1)

    # --- 4. Perform Prediction ---
    try:
        print(f"Running prediction on {img_file.name}...")
        # Set device explicitly if needed, otherwise model might default based on build
        # Add stream=False if processing single image, verbose=False for less output
        results = model.predict(source=str(img_file), device='mps', conf=conf_thresh, verbose=False, stream=False)
        print("Prediction complete.")
    except Exception as e:
        print(f"Error during prediction: {e}")
        sys.exit(1)

    # --- 5. Draw and Save ---
    output_filename = f"{img_file.stem}_prediction.png" # Save as PNG
    output_image_path = output_dir / output_filename

    draw_predictions(img_file, results, output_image_path, class_names, conf_thresh)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Run YOLO prediction on an image and draw bounding boxes.")
    parser.add_argument(
        '--model',
        type=str,
        required=True,
        help='Path to the trained YOLO model weights file (e.g., best.pt).'
    )
    parser.add_argument(
        '--image',
        type=str,
        required=True,
        help='Path to the input image file for prediction.'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        default='predictions', # Default output directory name
        help='Directory to save the output image with bounding boxes.'
    )
    parser.add_argument(
        '--conf',
        type=float,
        default=0.25, # Default confidence threshold
        help='Confidence threshold for displaying detections.'
    )
    parser.add_argument(
        '--data-yaml',
        type=str,
        default=None, # Optional path to data.yaml
        help='Path to the data.yaml file used during training to load class names. If omitted, uses default classes.'
    )

    args = parser.parse_args()
    main(args.model, args.image, args.output_dir, args.conf, args.data_yaml)
