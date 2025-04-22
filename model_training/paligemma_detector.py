import torch
from transformers import (
    PaliGemmaProcessor,
    PaliGemmaForConditionalGeneration,
)
from PIL import Image
import argparse
import re # For parsing the output string
import os # For checking file existence

# --- Configuration ---
MODEL_ID = "google/paligemma2-3b-mix-448"
# Define the classes the model should look for globally for this module
# This could be passed as an argument if more flexibility is needed later
TARGET_CLASSES = ["flip-flops", "helmet", "glove", "boots"]

# --- Global variables for model and processor (Load once) ---
_model = None
_processor = None
_device = None
_dtype = None

def _initialize_model_and_processor():
    """Loads the model and processor if they haven't been loaded yet."""
    global _model, _processor, _device, _dtype

    if _model is not None and _processor is not None:
        return # Already loaded

    # --- Device Setup ---
    print("Setting up device...")
    if torch.backends.mps.is_available():
        _device = torch.device("mps")
        _dtype = torch.float16
        print("Using MPS device (Apple Silicon).")
    elif torch.cuda.is_available():
        _device = torch.device("cuda")
        _dtype = torch.bfloat16
        print("Using CUDA device.")
    else:
        _device = torch.device("cpu")
        _dtype = torch.float32
        print("Using CPU device.")

    # --- Load Model and Processor ---
    print(f"Loading model and processor: {MODEL_ID}")
    try:
        _model = PaliGemmaForConditionalGeneration.from_pretrained(
            MODEL_ID,
            torch_dtype=_dtype,
        ).to(_device).eval()

        _processor = PaliGemmaProcessor.from_pretrained(MODEL_ID, use_fast=True)
        print("Model and processor loaded successfully.")
    except Exception as e:
        print(f"Error loading model or processor: {e}")
        _model = None
        _processor = None
        raise # Re-raise the exception

def parse_all_detections(decoded_output):
    """
    Parses the raw output string from PaliGemma and extracts all detected
    objects and their individual bounding boxes.

    Args:
        decoded_output (str): The raw string output from the model.

    Returns:
        list: A list of dictionaries, where each dictionary represents a
              detected object: {'label': str, 'box': (ymin, xmin, ymax, xmax)}
              The box coordinates are normalized (0-1000). Returns an empty
              list if no valid detections are found.
    """
    # Regex to capture coordinates and label (no underscore in <loc...>)
    # Allows for labels with spaces or hyphens
    pattern = re.compile(r"<loc(\d+)><loc(\d+)><loc(\d+)><loc(\d+)>\s*([\w\s-]+)")
    all_detections = []

    # Split the output in case of multiple detections separated by ';'
    segments = decoded_output.split(';')

    for segment in segments:
        segment = segment.strip()
        if not segment:
            continue

        match = pattern.search(segment)
        if match:
            ymin_str, xmin_str, ymax_str, xmax_str, raw_label = match.groups()
            label = raw_label.strip().lower() # Standardize label to lowercase

            try:
                # Append each valid detection individually
                all_detections.append({
                    'label': label,
                    'box': (int(ymin_str), int(xmin_str), int(ymax_str), int(xmax_str))
                })
            except ValueError:
                print(f"Warning: Could not parse coordinates in segment: {segment}")
                continue # Skip this segment if coordinates are invalid

    return all_detections

def get_detections_from_image(image_path):
    """
    Detects objects in an image using PaliGemma based on TARGET_CLASSES
    and returns all valid detections with their labels and normalized boxes.

    Args:
        image_path (str): Path to the input image file.

    Returns:
        list: A list of detected objects [{'label': str, 'box': (ymin, xmin, ymax, xmax)}],
              where coordinates are normalized (0-1000). Returns an empty list
              if no objects are detected or an error occurs.
    """
    global _model, _processor, _device, _dtype

    # --- Ensure model/processor are loaded ---
    try:
        _initialize_model_and_processor()
        if _model is None or _processor is None:
            print("Error: Model or processor failed to initialize.")
            return []
    except Exception as e:
        print(f"Failed to initialize model/processor: {e}")
        return []

    # --- Load Image ---
    if not os.path.exists(image_path):
        print(f"Error: Image file not found at '{image_path}'")
        return []
    try:
        # Get image dimensions without loading the full image into memory yet
        # This is useful if the image loading itself fails later
        with Image.open(image_path) as img:
             img_width, img_height = img.size
        # Now load for processing
        raw_image = Image.open(image_path).convert('RGB')
    except Exception as e:
        print(f"Error loading image {image_path}: {e}")
        return []

    # --- Prepare Prompt and Inputs ---
    # Create a prompt asking to detect all target classes
    detection_prompt = " ; ".join(TARGET_CLASSES)
    prompt = f"<image>\ndetect {detection_prompt}"
    # print(f"Using prompt: '{prompt}'") # Optional debug print

    try:
        model_inputs = _processor(
            text=prompt,
            images=raw_image,
            return_tensors="pt"
        ).to(_device).to(_dtype)
        input_len = model_inputs["input_ids"].shape[-1]
    except Exception as e:
        print(f"Error processing inputs for {image_path}: {e}")
        return []

    # --- Generate Raw Output ---
    decoded_output = ""
    try:
        with torch.inference_mode():
            generation = _model.generate(
                **model_inputs,
                # Increase max_new_tokens slightly in case of many detections
                max_new_tokens=150,
                do_sample=False
            )
            output_tokens = generation[0][input_len:]
            decoded_output = _processor.decode(output_tokens, skip_special_tokens=True)
            # print(f"Raw output for {image_path}: {decoded_output}") # Optional debug print
    except Exception as e:
        print(f"Error during generation for {image_path}: {e}")
        return []

    # --- Parse Detections ---
    detections = parse_all_detections(decoded_output)

    # Add image dimensions to each detection for later conversion
    for det in detections:
        det['img_width'] = img_width
        det['img_height'] = img_height

    return detections


# --- Main execution block for testing the module ---
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Test PaliGemma detection module.")
    parser.add_argument('--image', type=str, required=True, help='Path to the input image file for testing.')
    args = parser.parse_args()

    print(f"--- Testing Detection Module ---")
    print(f"Target Classes: {TARGET_CLASSES}")
    print(f"Test Image: {args.image}")

    # Call the main detection function
    detected_objects = get_detections_from_image(args.image)

    if detected_objects:
        print(f"\n--- Detected Objects ({len(detected_objects)}) ---")
        for i, obj in enumerate(detected_objects):
            print(f"  {i+1}: Label='{obj['label']}', Box(0-1000)={obj['box']}, ImgSize=({obj['img_width']}x{obj['img_height']})")
        print("---------------------------------\n")
    else:
        print(f"\nNo objects detected or an error occurred for {args.image}.\n")

    print("Module test finished.")
