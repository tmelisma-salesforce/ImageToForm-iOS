import os
import shutil
import argparse
import random
import yaml
from tqdm import tqdm # For progress bar
from pathlib import Path
import sys # For error messages
import math # For ceiling function in splitting

# Import the detection function from the refactored detector module
# Assumes paligemma_detector.py is in the same directory or Python path
try:
    # Ensure the detector module initializes its model/processor
    from paligemma_detector import get_detections_from_image, _initialize_model_and_processor
except ImportError:
    print("Error: Could not import from 'paligemma_detector.py'.")
    print("Ensure 'paligemma_detector.py' is in the same directory or your PYTHONPATH.")
    sys.exit(1) # Exit if import fails

# --- Configuration ---
# Define the complete list of classes for the YOLO dataset
CLASSES = ["flip-flops", "helmet", "glove", "boots"]
CLASS_MAP = {name: i for i, name in enumerate(CLASSES)}

# Define dataset split ratios
TRAIN_RATIO = 0.70
VAL_RATIO = 0.15
TEST_RATIO = 0.15 # Should sum to 1.0 with TRAIN and VAL

# Supported image extensions (lowercase)
IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png']

def convert_to_yolo_format(detection, class_map):
    """
    Converts a single detection from PaliGemma format to YOLO format.
    (Function remains the same as previous version)
    """
    label = detection['label']
    if label not in class_map:
        return None

    class_id = class_map[label]
    img_width = detection['img_width']
    img_height = detection['img_height']

    if img_width <= 0 or img_height <= 0:
         return None

    ymin, xmin, ymax, xmax = detection['box']

    ymin = max(0, min(ymin, 1000))
    xmin = max(0, min(xmin, 1000))
    ymax = max(0, min(ymax, 1000))
    xmax = max(0, min(xmax, 1000))

    if xmin >= xmax or ymin >= ymax:
        return None

    x_center_norm = ((xmin + xmax) / 2) / 1000
    y_center_norm = ((ymin + ymax) / 2) / 1000
    width_norm = (xmax - xmin) / 1000
    height_norm = (ymax - ymin) / 1000

    x_center = max(0.0, min(x_center_norm, 1.0))
    y_center = max(0.0, min(y_center_norm, 1.0))
    width = max(0.0, min(width_norm, 1.0))
    height = max(0.0, min(height_norm, 1.0))

    if width <= 0 or height <= 0:
        return None

    return f"{class_id} {x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}"

def process_image_batch(image_paths_with_split, output_path, required_pairs):
    """Processes a batch of images for a specific split (train/val/test)."""
    processed_count = 0
    copied_count = 0
    skipped_count = 0
    error_count = 0
    no_target_object_warning_count = 0
    required_missing_warning_count = 0

    img_base_path = output_path / "images"
    lbl_base_path = output_path / "labels"

    for split, source_img_path, source_dir_name in tqdm(image_paths_with_split, desc=f"Processing {len(image_paths_with_split)} images"):

        target_img_dir = img_base_path / split
        target_lbl_dir = lbl_base_path / split

        # Define target paths
        img_filename = source_img_path.name
        target_img_path = target_img_dir / img_filename
        target_lbl_path = target_lbl_dir / (source_img_path.stem + ".txt")

        # Idempotency Check 1: Skip if label file already exists in target
        if target_lbl_path.exists():
            skipped_count += 1
            # Idempotency Check 2: Ensure the image also exists, copy if missing
            if not target_img_path.exists() and source_img_path.exists():
                 try:
                     shutil.copy2(str(source_img_path), str(target_img_path))
                     copied_count += 1
                 except Exception as e:
                     tqdm.write(f"\nWarning: Error copying existing image {source_img_path.name} during idempotency check: {e}")
            continue

        # Idempotency Check 3: Check if source image still exists
        if not source_img_path.exists():
            skipped_count +=1
            continue

        # Get detections
        detections = get_detections_from_image(str(source_img_path))

        if detections is None: # Error during detection
            tqdm.write(f"\nError detecting objects in {source_img_path.name}. Skipping.")
            error_count += 1
            continue

        # Convert detections to YOLO format
        yolo_lines = []
        detected_class_ids = set()
        for det in detections:
            yolo_str = convert_to_yolo_format(det, CLASS_MAP)
            if yolo_str:
                yolo_lines.append(yolo_str)
                try:
                    class_id = int(yolo_str.split()[0])
                    detected_class_ids.add(class_id)
                except (IndexError, ValueError):
                    tqdm.write(f"\nWarning: Could not parse class ID from YOLO line: '{yolo_str}'")

        # --- Warnings ---
        if not yolo_lines:
            tqdm.write(f"\nWARNING: No target objects ({', '.join(CLASSES)}) found in image: {source_img_path.name}")
            no_target_object_warning_count += 1

        if source_dir_name in required_pairs:
            req_class1_name, req_class2_name = required_pairs[source_dir_name]
            try:
                req_id1 = CLASS_MAP[req_class1_name]
                req_id2 = CLASS_MAP[req_class2_name]
                missing_classes = []
                if req_id1 not in detected_class_ids: missing_classes.append(req_class1_name)
                if req_id2 not in detected_class_ids: missing_classes.append(req_class2_name)
                if missing_classes:
                    tqdm.write(f"\nWARNING: Image {source_img_path.name} from '{source_dir_name}' is missing required object(s): {', '.join(missing_classes)}")
                    required_missing_warning_count += 1
            except KeyError as e:
                 tqdm.write(f"\nERROR: Class name '{e}' specified in --require-both not found in main CLASSES list. Cannot check requirement for {source_img_path.name}")

        # --- Write Label File ---
        try:
            with open(target_lbl_path, 'w') as f:
                f.write("\n".join(yolo_lines))
        except Exception as e:
            tqdm.write(f"\nError writing label file {target_lbl_path}: {e}")
            error_count += 1
            continue

        # --- Copy Image File ---
        try:
            shutil.copy2(str(source_img_path), str(target_img_path))
            processed_count += 1
            copied_count += 1
        except Exception as e:
            tqdm.write(f"\nError copying image file {source_img_path.name}: {e}")
            if target_lbl_path.exists():
                try: target_lbl_path.unlink()
                except OSError: pass
            error_count += 1

    return {
        "processed": processed_count,
        "copied": copied_count,
        "skipped": skipped_count,
        "errors": error_count,
        "no_target_warnings": no_target_object_warning_count,
        "required_missing_warnings": required_missing_warning_count
    }


def main(input_dirs, output_dir, required_pairs):
    """Generates YOLO dataset from input image directories using stratified split."""

    output_path = Path(output_dir)
    print(f"Output directory: {output_path.resolve()}")

    # --- 0. Initialize Detector Model ---
    try:
        _initialize_model_and_processor()
    except Exception as e:
        print(f"Fatal Error: Could not initialize PaliGemma model: {e}")
        sys.exit(1)

    # --- 1. Setup Output Directories ---
    print("Setting up output directories...")
    img_train_path = output_path / "images" / "train"
    lbl_train_path = output_path / "labels" / "train"
    img_val_path = output_path / "images" / "val"
    lbl_val_path = output_path / "labels" / "val"
    img_test_path = output_path / "images" / "test"
    lbl_test_path = output_path / "labels" / "test"

    # Create directories idempotently
    for p in [img_train_path, lbl_train_path, img_val_path, lbl_val_path, img_test_path, lbl_test_path]:
        p.mkdir(parents=True, exist_ok=True)

    # --- 2. Collect Images Grouped by Source Directory ---
    print("Collecting and grouping image files by source directory...")
    grouped_images = {} # {source_dir_name: [Path objects]}
    for input_dir in input_dirs:
        input_path = Path(input_dir)
        if not input_path.is_dir():
            print(f"Warning: Input path '{input_dir}' is not a directory. Skipping.")
            continue
        source_dir_name = input_path.name
        grouped_images[source_dir_name] = []
        print(f"Scanning directory: {input_path.resolve()} (Group: '{source_dir_name}')")
        for item in input_path.iterdir():
            if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS:
                grouped_images[source_dir_name].append(item.resolve())

    if not any(grouped_images.values()):
        print("Error: No image files found in the specified input directories.")
        return

    # --- 3. Stratified Splitting ---
    print("Performing stratified split...")
    all_splits_data = [] # List of tuples: (split_name, image_path, source_dir_name)

    for source_dir_name, image_list in grouped_images.items():
        if not image_list:
            print(f"Warning: No images found in group '{source_dir_name}'.")
            continue

        random.shuffle(image_list) # Shuffle within the group
        n_images = len(image_list)
        n_train = math.ceil(n_images * TRAIN_RATIO) # Use ceil to avoid losing images due to rounding
        n_val = math.ceil(n_images * VAL_RATIO)
        # Ensure at least 1 image in val/test if possible and train has enough
        if n_images > 2 and n_train >= n_images - 1: # If train takes almost all
             n_train = n_images - 2 # Leave at least one for val, one for test
             n_val = 1
             n_test = 1
        elif n_images > 1 and n_train == n_images: # If train takes all
             n_train = n_images - 1 # Leave one for val
             n_val = 1
             n_test = 0
        else:
             n_test = n_images - n_train - n_val # Remainder goes to test
             if n_test < 0: # Handle potential rounding issues leading to negative test count
                 n_test = 0
                 if n_train + n_val > n_images: # If train+val exceed total, adjust val
                     n_val = n_images - n_train


        print(f"  Group '{source_dir_name}' ({n_images} images): Train={n_train}, Val={n_val}, Test={n_test}")

        # Assign images to splits
        current_idx = 0
        for i in range(n_train):
            all_splits_data.append(("train", image_list[current_idx], source_dir_name))
            current_idx += 1
        for i in range(n_val):
            if current_idx < n_images: # Check bounds
                 all_splits_data.append(("val", image_list[current_idx], source_dir_name))
                 current_idx += 1
        for i in range(n_test):
             if current_idx < n_images: # Check bounds
                 all_splits_data.append(("test", image_list[current_idx], source_dir_name))
                 current_idx += 1

    print(f"Total images assigned to splits: {len(all_splits_data)}")

    # --- 4. Process Images and Generate Labels (using the combined split list) ---
    print("Processing images and generating YOLO labels based on stratified split...")
    results = process_image_batch(all_splits_data, output_path, required_pairs)

    print(f"\nImage processing complete.")
    print(f"  Labels/Images Processed in this run: {results['processed']}")
    print(f"  Images Copied (incl. idempotency checks): {results['copied']}")
    print(f"  Skipped (already done): {results['skipped']}")
    print(f"  Warnings (No target objects found): {results['no_target_warnings']}")
    print(f"  Warnings (Required objects missing): {results['required_missing_warnings']}")
    print(f"  Errors: {results['errors']}")

    # --- 5. Create data.yaml File ---
    print("Creating data.yaml file...")
    data_yaml_content = {
        'path': str(output_path.resolve()),
        'train': os.path.join('images', 'train'),
        'val': os.path.join('images', 'val'),
        'test': os.path.join('images', 'test'),
        'nc': len(CLASSES),
        'names': CLASSES
    }
    data_yaml_path = output_path / "data.yaml"
    try:
        with open(data_yaml_path, 'w') as f:
            yaml.dump(data_yaml_content, f, sort_keys=False, default_flow_style=None)
        print(f"Successfully created '{data_yaml_path.resolve()}'")
    except Exception as e:
        print(f"Error creating data.yaml file: {e}")

    print("\nDataset generation finished.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate YOLO dataset using PaliGemma detections (Stratified Split).")
    parser.add_argument(
        '--input-dirs',
        nargs='+',
        required=True,
        help='List of input directories containing raw images (e.g., flip-flops boots helmet-glove).'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        required=True,
        help='Directory where the YOLO dataset will be created.'
    )
    parser.add_argument(
        '--require-both',
        nargs=3,
        action='append',
        metavar=('DIR_NAME', 'CLASS1', 'CLASS2'),
        help='Specify an input directory name and two class names that MUST both be detected in images from that directory. Example: --require-both helmet-glove helmet glove',
        default=[]
    )
    args = parser.parse_args()

    # Validate input directories exist
    valid_input_dirs = []
    input_dir_names = set()
    for d in args.input_dirs:
        p = Path(d)
        if p.is_dir():
            valid_input_dirs.append(d)
            input_dir_names.add(p.name)
        else:
            print(f"Warning: Input directory '{d}' not found. It will be ignored.")

    if not valid_input_dirs:
        print("Error: No valid input directories found. Exiting.")
        sys.exit(1)

    # Process and validate --require-both arguments
    required_pairs = {}
    valid_requirement = True
    for req in args.require_both:
        dir_name, class1, class2 = req
        if dir_name not in input_dir_names:
            print(f"Error: Directory name '{dir_name}' specified in --require-both is not among the valid input directory base names: {input_dir_names}")
            valid_requirement = False
        if class1 not in CLASS_MAP:
            print(f"Error: Class name '{class1}' specified in --require-both is not in the defined CLASSES: {CLASSES}")
            valid_requirement = False
        if class2 not in CLASS_MAP:
            print(f"Error: Class name '{class2}' specified in --require-both is not in the defined CLASSES: {CLASSES}")
            valid_requirement = False
        if valid_requirement:
             required_pairs[dir_name] = (class1.lower(), class2.lower())
        else:
            break

    if not valid_requirement:
        print("Exiting due to invalid --require-both arguments.")
        sys.exit(1)

    if required_pairs:
        print("Required pairs specified:")
        for dir_name, classes in required_pairs.items():
            print(f"  - In directory '{dir_name}': Must find both '{classes[0]}' and '{classes[1]}'")

    main(valid_input_dirs, args.output_dir, required_pairs)
