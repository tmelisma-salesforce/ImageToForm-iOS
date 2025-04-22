import torch
from transformers import (
    PaliGemmaProcessor,
    PaliGemmaForConditionalGeneration,
)
from PIL import Image, UnidentifiedImageError
import argparse
import re
import os
import sys

# --- Configuration ---
MODEL_ID = "google/paligemma2-3b-mix-448"
# TARGET_CLASSES removed - detection targets will be passed in

# --- Global variables ---
_model = None
_processor = None
_device = None
_dtype = None

def _initialize_model_and_processor():
    """Loads the model and processor if they haven't been loaded yet."""
    global _model, _processor, _device, _dtype
    if _model is not None and _processor is not None: return

    print("Setting up device...")
    if torch.backends.mps.is_available():
        _device = torch.device("mps"); _dtype = torch.float16
        print("Using MPS device (Apple Silicon).")
    elif torch.cuda.is_available():
        _device = torch.device("cuda"); _dtype = torch.bfloat16
        print("Using CUDA device.")
    else:
        _device = torch.device("cpu"); _dtype = torch.float32
        print("Using CPU device.")

    print(f"Loading model and processor: {MODEL_ID}")
    try:
        _model = PaliGemmaForConditionalGeneration.from_pretrained(
            MODEL_ID, torch_dtype=_dtype,
        ).to(_device).eval()
        _processor = PaliGemmaProcessor.from_pretrained(MODEL_ID, use_fast=True)
        print("Model and processor loaded successfully.")
    except Exception as e:
        print(f"Error loading model or processor: {e}")
        _model = None; _processor = None
        raise

def parse_all_detections(decoded_output):
    """
    Parses the raw output string from PaliGemma and extracts all detected
    objects and their individual bounding boxes.
    (Function remains the same)
    """
    pattern = re.compile(r"<loc(\d+)><loc(\d+)><loc(\d+)><loc(\d+)>\s*([\w\s-]+)")
    all_detections = []
    segments = decoded_output.split(';')

    for segment in segments:
        segment = segment.strip()
        if not segment: continue
        match = pattern.search(segment)
        if match:
            ymin_str, xmin_str, ymax_str, xmax_str, raw_label = match.groups()
            label = raw_label.strip().lower()
            try:
                all_detections.append({
                    'label': label,
                    'box': (int(ymin_str), int(xmin_str), int(ymax_str), int(xmax_str))
                })
            except ValueError:
                continue
    return all_detections

# --- Updated Function Signature ---
def get_detections_from_image(image_path, classes_to_detect):
    """
    Detects specified objects in an image using PaliGemma and returns
    all valid detections with their labels and normalized boxes.

    Args:
        image_path (str): Path to the input image file.
        classes_to_detect (list): A list of class names (strings) to ask
                                  PaliGemma to detect.

    Returns:
        list: A list of detected objects [{'label': str, 'box': (ymin, xmin, ymax, xmax)}],
              where coordinates are normalized (0-1000). Returns an empty list
              if no objects are detected or an error occurs.
    """
    global _model, _processor, _device, _dtype
    # print(f"DEBUG: Attempting to process image: {image_path}") # Keep debugging minimal now
    # sys.stdout.flush()

    # --- Ensure model/processor are loaded ---
    try:
        _initialize_model_and_processor()
        if _model is None or _processor is None:
            print(f"ERROR: Model or processor not initialized when processing {image_path}.")
            return []
    except Exception as e:
        print(f"ERROR: Failed to initialize model/processor for {image_path}: {e}")
        return []

    # --- Load Image ---
    raw_image = None
    img_width, img_height = 0, 0
    if not os.path.exists(image_path):
        print(f"ERROR: Image file not found at '{image_path}'")
        return []
    try:
        with Image.open(image_path) as img:
             img.verify()
             raw_image = Image.open(image_path).convert('RGB')
             img_width, img_height = raw_image.size
        # print(f"DEBUG: Successfully loaded image {image_path} ({img_width}x{img_height}).")
    except UnidentifiedImageError:
        print(f"ERROR: Cannot identify image file (corrupted or wrong format): {image_path}")
        return []
    except FileNotFoundError:
        print(f"ERROR: Image file not found (during open): {image_path}")
        return []
    except Exception as e:
        print(f"ERROR: Failed to load image {image_path}: {type(e).__name__} - {e}")
        return []

    # --- Prepare Prompt and Inputs ---
    if not classes_to_detect:
         print(f"Warning: No classes specified to detect for image {image_path}. Skipping detection.")
         return []

    # --- Dynamically create the prompt ---
    detection_prompt = " ; ".join(classes_to_detect) # Join requested classes
    prompt = f"<image>\ndetect {detection_prompt}"
    # print(f"DEBUG: Using prompt: '{prompt}' for {image_path}") # Optional debug

    try:
        model_inputs = _processor(
            text=prompt, images=raw_image, return_tensors="pt"
        ).to(_device).to(_dtype)
        input_len = model_inputs["input_ids"].shape[-1]
    except Exception as e:
        print(f"ERROR: Failed processing inputs for {image_path}: {e}")
        return []

    # --- Generate Raw Output ---
    decoded_output = ""
    # print(f"DEBUG: Starting model.generate() for {image_path}...")
    # sys.stdout.flush()
    try:
        with torch.inference_mode():
            generation = _model.generate(
                **model_inputs, max_new_tokens=150, do_sample=False
            )
        # print(f"DEBUG: Finished model.generate() for {image_path}.")
        # sys.stdout.flush()
        output_tokens = generation[0][input_len:]
        decoded_output = _processor.decode(output_tokens, skip_special_tokens=True)
    except Exception as e:
        print(f"ERROR: Exception during model.generate() for {image_path}: {type(e).__name__} - {e}")
        return []

    # --- Parse Detections ---
    # Parse whatever the model returned, even if it wasn't asked for
    detections = parse_all_detections(decoded_output)

    # Add image dimensions to each detection
    for det in detections:
        det['img_width'] = img_width
        det['img_height'] = img_height

    # print(f"DEBUG: Found {len(detections)} potential objects in {image_path}.")
    # sys.stdout.flush()
    return detections


# --- Main execution block for testing ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test PaliGemma detection module with targeted classes.")
    parser.add_argument('--image', type=str, required=True, help='Path to the input image file for testing.')
    parser.add_argument('--detect', nargs='+', required=True, help='List of classes to detect (e.g., boots or helmet glove).')
    args = parser.parse_args()

    print(f"--- Testing Detection Module ---")
    print(f"Classes to Detect: {args.detect}")
    print(f"Test Image: {args.image}")

    # Call the main detection function with specified classes
    detected_objects = get_detections_from_image(args.image, args.detect)

    if detected_objects:
        print(f"\n--- Detected Objects ({len(detected_objects)}) ---")
        # Note: The model might still return objects other than those requested
        for i, obj in enumerate(detected_objects):
            print(f"  {i+1}: Label='{obj['label']}', Box(0-1000)={obj['box']}, ImgSize=({obj['img_width']}x{obj['img_height']})")
        print("---------------------------------\n")
    else:
        print(f"\nNo objects detected or an error occurred for {args.image}.\n")

    print("Module test finished.")
