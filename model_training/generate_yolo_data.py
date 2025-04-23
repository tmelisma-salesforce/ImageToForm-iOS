import os
import shutil
import argparse
import random
import yaml
from tqdm import tqdm
from pathlib import Path
import sys
import math

# Import the UPDATED detection function
try:
    # Make sure the detector script is named correctly or update the import
    from paligemma_detector import get_detections_from_image, _initialize_model_and_processor
except ImportError:
    print("Error: Could not import from 'paligemma_detector_refactored_v2.py'.")
    print("Ensure the updated detector script ('paligemma_detector_refactored_v2.py') is in the same directory or your PYTHONPATH.")
    sys.exit(1)

# --- Configuration ---
CLASSES = ["flip-flops", "helmet", "glove", "boots"]
CLASS_MAP = {name: i for i, name in enumerate(CLASSES)}
TRAIN_RATIO = 0.70
VAL_RATIO = 0.15
TEST_RATIO = 0.15
IMAGE_EXTENSIONS = ['.jpg', '.jpeg', '.png']

# --- Helper Functions (yolo_coord_conversion, paligemma_to_pixels) ---
def yolo_coord_conversion(box_coords, img_width, img_height):
    if img_width <= 0 or img_height <= 0: return None
    xmin, ymin, xmax, ymax = box_coords
    xmin = max(0, xmin); ymin = max(0, ymin)
    xmax = min(img_width, xmax); ymax = min(img_height, ymax)
    if xmin >= xmax or ymin >= ymax: return None
    x_center = ((xmin + xmax) / 2) / img_width
    y_center = ((ymin + ymax) / 2) / img_height
    width = (xmax - xmin) / img_width
    height = (ymax - ymin) / img_height
    x_center = max(0.0, min(x_center, 1.0)); y_center = max(0.0, min(y_center, 1.0))
    width = max(0.0, min(width, 1.0)); height = max(0.0, min(height, 1.0))
    if width <= 0 or height <= 0: return None
    return f"{x_center:.6f} {y_center:.6f} {width:.6f} {height:.6f}"

def paligemma_to_pixels(box_norm, img_width, img_height):
    if img_width <= 0 or img_height <= 0: return None
    ymin_norm, xmin_norm, ymax_norm, xmax_norm = box_norm
    ymin_norm=max(0,min(ymin_norm,1000)); xmin_norm=max(0,min(xmin_norm,1000))
    ymax_norm=max(0,min(ymax_norm,1000)); xmax_norm=max(0,min(xmax_norm,1000))
    xmin = round((xmin_norm / 1000) * img_width); ymin = round((ymin_norm / 1000) * img_height)
    xmax = round((xmax_norm / 1000) * img_width); ymax = round((ymax_norm / 1000) * img_height)
    if xmin >= xmax or ymin >= ymax: return None
    return (xmin, ymin, xmax, ymax)
# --- End Helper Functions ---


def process_image_batch(image_paths_with_split, output_path, required_pairs, single_class_dirs):
    """Processes a batch of images for a specific split (train/val/test)."""
    processed_count = 0; copied_count = 0; skipped_count = 0
    error_count = 0; no_target_object_warning_count = 0
    required_missing_warning_count = 0

    img_base_path = output_path / "images"
    lbl_base_path = output_path / "labels"

    for split, source_img_path, source_dir_name in tqdm(image_paths_with_split, desc=f"Processing {len(image_paths_with_split)} images"):

        target_img_dir = img_base_path / split
        target_lbl_dir = lbl_base_path / split
        img_filename = source_img_path.name # Keep original filename
        target_img_path = target_img_dir / img_filename
        target_lbl_path = target_lbl_dir / (source_img_path.stem + ".txt")

        # Idempotency Check
        if target_lbl_path.exists():
            skipped_count += 1
            if not target_img_path.exists() and source_img_path.exists():
                 try:
                     shutil.copy2(str(source_img_path), str(target_img_path))
                     copied_count += 1
                 except Exception as e:
                     tqdm.write(f"\nWarning: Error copying existing image {source_img_path.name} during idempotency check: {e}")
            continue
        if not source_img_path.exists():
            skipped_count +=1
            continue

        # --- Determine classes to detect based on source dir ---
        classes_to_request = []
        expected_label_from_dir = single_class_dirs.get(source_dir_name)
        allowed_labels_in_dir = set()

        if expected_label_from_dir:
            classes_to_request = [expected_label_from_dir]
        elif source_dir_name in required_pairs:
            classes_to_request = list(required_pairs[source_dir_name])
            allowed_labels_in_dir.update(required_pairs[source_dir_name])
        else:
            classes_to_request = CLASSES
            # tqdm.write(f"Note: Requesting all classes for image {source_img_path.name} from unclassified directory '{source_dir_name}'.")


        # --- Get detections using the targeted prompt ---
        detections = get_detections_from_image(str(source_img_path), classes_to_request)

        if detections is None: # Error during detection
            tqdm.write(f"\nError detecting objects in {source_img_path.name}. Skipping.")
            error_count += 1
            continue

        yolo_lines = []
        detected_class_ids_final = set()

        # --- Label Enforcement Logic ---
        for det in detections:
            pali_label = det['label']
            label_to_use = None
            class_id = -1

            if expected_label_from_dir:
                label_to_use = expected_label_from_dir
            elif allowed_labels_in_dir:
                if pali_label in allowed_labels_in_dir:
                    label_to_use = pali_label
            else:
                 if pali_label in CLASS_MAP:
                     label_to_use = pali_label

            if label_to_use:
                try:
                    class_id = CLASS_MAP[label_to_use]
                    pixel_box = paligemma_to_pixels(det['box'], det['img_width'], det['img_height'])
                    if pixel_box:
                        yolo_coords_str = yolo_coord_conversion(pixel_box, det['img_width'], det['img_height'])
                        if yolo_coords_str:
                            yolo_lines.append(f"{class_id} {yolo_coords_str}")
                            detected_class_ids_final.add(class_id)
                except KeyError:
                     tqdm.write(f"\nWarning: Label '{label_to_use}' determined for {source_img_path.name} not in CLASS_MAP. Skipping detection.")
                except Exception as e:
                     tqdm.write(f"\nError converting coordinates for {source_img_path.name} (Label: {label_to_use}): {e}")
        # --- End Label Enforcement ---


        # --- Warnings ---
        if not yolo_lines:
            tqdm.write(f"\nWARNING: No target objects written to label file for image: {source_img_path.name}")
            no_target_object_warning_count += 1

        if source_dir_name in required_pairs:
            req_class1_name, req_class2_name = required_pairs[source_dir_name]
            try:
                req_id1 = CLASS_MAP[req_class1_name]
                req_id2 = CLASS_MAP[req_class2_name]
                missing_classes = []
                if req_id1 not in detected_class_ids_final: missing_classes.append(req_class1_name)
                if req_id2 not in detected_class_ids_final: missing_classes.append(req_class2_name)
                if missing_classes:
                    tqdm.write(f"\nWARNING: Image {source_img_path.name} from '{source_dir_name}' is missing required object(s) in final labels: {', '.join(missing_classes)}")
                    required_missing_warning_count += 1
            except KeyError as e:
                 tqdm.write(f"\nERROR: Class name '{e}' specified in --require-both not found in main CLASSES list.")

        # --- Write Label File & Copy Image ---
        try:
            with open(target_lbl_path, 'w') as f: f.write("\n".join(yolo_lines))
            shutil.copy2(str(source_img_path), str(target_img_path))
            processed_count += 1
            copied_count += 1
        except Exception as e:
            tqdm.write(f"\nError writing label or copying image for {source_img_path.name}: {e}")
            if target_lbl_path.exists():
                try: target_lbl_path.unlink()
                except OSError: pass
            if target_img_path.exists():
                 try: target_img_path.unlink()
                 except OSError: pass
            error_count += 1


    return {
        "processed": processed_count, "copied": copied_count, "skipped": skipped_count,
        "errors": error_count, "no_target_warnings": no_target_object_warning_count,
        "required_missing_warnings": required_missing_warning_count
    }


def main(input_dirs, output_dir, required_pairs_args):
    """Generates YOLO dataset using stratified split and targeted detection prompts."""

    output_path = Path(output_dir)
    print(f"Output directory: {output_path.resolve()}")

    # --- 0. Initialize Detector Model ---
    try: _initialize_model_and_processor()
    except Exception as e: print(f"Fatal Error: Could not initialize PaliGemma model: {e}"); sys.exit(1)

    # --- 1. Setup Output Directories ---
    print("Setting up output directories...")
    img_train_path=output_path/"images"/"train"; lbl_train_path=output_path/"labels"/"train"
    img_val_path=output_path/"images"/"val"; lbl_val_path=output_path/"labels"/"val"
    img_test_path=output_path/"images"/"test"; lbl_test_path=output_path/"labels"/"test"
    for p in [img_train_path, lbl_train_path, img_val_path, lbl_val_path, img_test_path, lbl_test_path]:
        p.mkdir(parents=True, exist_ok=True)

    # --- Process --require-both args ---
    required_pairs = {}; multi_class_source_dirs = set(); valid_requirement = True
    for req in required_pairs_args:
        dir_name, class1, class2 = req
        if class1 not in CLASS_MAP or class2 not in CLASS_MAP:
            print(f"Error: Class names '{class1}' or '{class2}' in --require-both not in CLASSES: {CLASSES}"); valid_requirement = False; break
        required_pairs[dir_name] = (class1.lower(), class2.lower()); multi_class_source_dirs.add(dir_name)
    if not valid_requirement: print("Exiting due to invalid class names in --require-both."); sys.exit(1)

    # --- 2. Collect Images Grouped by Source Directory ---
    print("Collecting and grouping image files by source directory...")
    grouped_images = {}; single_class_dirs = {}; input_dir_names = set()
    for input_dir in input_dirs:
        input_path = Path(input_dir); source_dir_name = input_path.name
        if not input_path.is_dir(): print(f"Warning: Input path '{input_dir}' not directory. Skipping."); continue
        input_dir_names.add(source_dir_name); grouped_images[source_dir_name] = []
        print(f"Scanning directory: {input_path.resolve()} (Group: '{source_dir_name}')")
        # Determine dir type
        if source_dir_name in CLASS_MAP and source_dir_name not in multi_class_source_dirs:
            single_class_dirs[source_dir_name] = source_dir_name
            print(f"  Identified '{source_dir_name}' as single-class. Will request ONLY '{source_dir_name}' and enforce label.")
        elif source_dir_name in multi_class_source_dirs:
             print(f"  Identified '{source_dir_name}' as multi-class. Will request ONLY {required_pairs[source_dir_name]} and keep only those labels.")
        else: print(f"  Warning: Dir '{source_dir_name}' type unknown. Will request ALL classes ({CLASSES}).")
        # Collect files
        for item in input_path.iterdir():
            if item.is_file() and item.suffix.lower() in IMAGE_EXTENSIONS: grouped_images[source_dir_name].append(item.resolve())
    if not any(grouped_images.values()): print("Error: No image files found."); return
    # Validate require_both dirs exist
    for dir_name in required_pairs.keys():
         if dir_name not in input_dir_names: print(f"Error: Dir '{dir_name}' in --require-both not found. Found: {input_dir_names}"); sys.exit(1)
    if required_pairs: print("Required pairs specified:", required_pairs)

    # --- 3. Stratified Splitting ---
    print("Performing stratified split...")
    all_splits_data = []
    # --- FIX for UnboundLocalError ---
    for source_dir_name, image_list in grouped_images.items():
        if not image_list:
            print(f"Warning: No images found in group '{source_dir_name}'. Skipping split for this group.")
            continue # Skip this iteration if the list is empty

        # Now we know image_list is not empty
        random.shuffle(image_list)
        n_images = len(image_list) # Define n_images safely here

        # Calculate splits
        n_train = math.ceil(n_images * TRAIN_RATIO)
        n_val = math.ceil(n_images * VAL_RATIO)
        # Adjust counts to ensure val/test get at least one if possible
        if n_images > 2 and n_train >= n_images - 1: n_train = n_images - 2; n_val = 1; n_test = 1
        elif n_images > 1 and n_train == n_images: n_train = n_images - 1; n_val = 1; n_test = 0
        else:
             n_test = n_images - n_train - n_val
             if n_test < 0: n_test = 0; n_val = n_images - n_train # Ensure val doesn't overflow

        print(f"  Group '{source_dir_name}' ({n_images} images): Train={n_train}, Val={n_val}, Test={n_test}")
        current_idx = 0
        # Assign images to splits
        for i in range(n_train):
            if current_idx < n_images: # Bounds check
                 all_splits_data.append(("train", image_list[current_idx], source_dir_name))
                 current_idx += 1
        for i in range(n_val):
            if current_idx < n_images:
                 all_splits_data.append(("val", image_list[current_idx], source_dir_name))
                 current_idx += 1
        for i in range(n_test):
             if current_idx < n_images:
                 all_splits_data.append(("test", image_list[current_idx], source_dir_name))
                 current_idx += 1
    # --- End FIX ---
    print(f"Total images assigned to splits: {len(all_splits_data)}")


    # --- 4. Process Images and Generate Labels ---
    print("Processing images and generating YOLO labels (using targeted prompts)...")
    results = process_image_batch(all_splits_data, output_path, required_pairs, single_class_dirs)
    print(f"\nImage processing complete."); print(f"  Processed: {results['processed']}, Copied: {results['copied']}, Skipped: {results['skipped']}")
    print(f"  Warnings (No target): {results['no_target_warnings']}, Warnings (Required missing): {results['required_missing_warnings']}, Errors: {results['errors']}")

    # --- 5. Create data.yaml File ---
    print("Creating data.yaml file...")
    data_yaml_content = {'path': str(output_path.resolve()), 'train': os.path.join('images', 'train'), 'val': os.path.join('images', 'val'), 'test': os.path.join('images', 'test'), 'nc': len(CLASSES), 'names': CLASSES}
    data_yaml_path = output_path / "data.yaml"
    try:
        with open(data_yaml_path, 'w') as f: yaml.dump(data_yaml_content, f, sort_keys=False, default_flow_style=None)
        print(f"Successfully created '{data_yaml_path.resolve()}'")
    except Exception as e: print(f"Error creating data.yaml file: {e}")
    print("\nDataset generation finished.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate YOLO dataset (Stratified Split, Targeted Detect, Enforce Labels).")
    parser.add_argument('--input-dirs', nargs='+', required=True, help='List of input directories containing raw images.')
    parser.add_argument('--output-dir', type=str, required=True, help='Directory where the YOLO dataset will be created.')
    parser.add_argument('--require-both', nargs=3, action='append', metavar=('DIR_NAME', 'CLASS1', 'CLASS2'), help='Specify input dir name and two classes that MUST both be detected. Example: --require-both helmet-glove helmet glove', default=[])
    args = parser.parse_args()

    valid_input_dirs = []; input_dir_names = set()
    for d in args.input_dirs:
        p = Path(d);
        if p.is_dir(): valid_input_dirs.append(d); input_dir_names.add(p.name)
        else: print(f"Warning: Input directory '{d}' not found. Ignored.")
    if not valid_input_dirs: print("Error: No valid input directories found. Exiting."); sys.exit(1)

    # Pass args.require_both directly to main
    main(valid_input_dirs, args.output_dir, args.require_both)
