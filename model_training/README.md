# YOLO Object Detection Dataset Generation Pipeline

This project provides a pipeline to generate images using DALL-E 3, automatically annotate them for object detection using PaliGemma, and format the results into a YOLO-compatible dataset. It also includes a script to visualize the generated annotations for verification.

**Target Classes:** flip-flops, helmet, glove, boots

## Prerequisites

* Python 3.8 or higher
* `pip` (Python package installer)
* An OpenAI API Key (for DALL-E 3 image generation)

## Setup

1.  **Clone the Repository (if applicable):**
    If this project is in a Git repository, clone it first:
    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```
    Otherwise, ensure all the scripts (`generate_dalle_images.py`, `paligemma_detector.py`, `generate_yolo_data.py`, `draw_yolo_boxes.py`) are in the same directory.

2.  **Create and Activate Virtual Environment:**
    It's highly recommended to use a virtual environment to manage dependencies.
    ```bash
    # Create a virtual environment named .venv
    python3 -m venv .venv

    # Activate the virtual environment
    # On macOS/Linux:
    source .venv/bin/activate
    # On Windows:
    # .venv\Scripts\activate
    ```
    You should see `(.venv)` at the beginning of your terminal prompt.

3.  **Install Dependencies:**
    Install the required Python libraries:
    ```bash
    pip install openai python-dotenv requests Pillow torch transformers torchvision PyYAML tqdm accelerate bitsandbytes
    ```
    *(Note: `bitsandbytes` and `accelerate` help with model loading and memory efficiency, especially on GPUs/MPS).*

4.  **Create `.env` File:**
    Create a file named `.env` in the root directory of the project and add your OpenAI API key:
    ```
    OPENAI_API_KEY='your_openai_api_key_here'
    ```
    Replace `your_openai_api_key_here` with your actual secret key. **Do not commit this file to version control.**

## Directory Structure

* **Source Image Directories:** Create separate directories for your raw input images based on their primary content. The `generate_yolo_data.py` script expects these directories to be provided as input. Example structure:
    ```
    project_directory/
    ├── flip-flops/       # Images containing only flip-flops
    │   └── *.jpg
    ├── boots/            # Images containing only boots
    │   └── *.png
    └── helmet-glove/     # Images containing both helmet AND glove
        └── *.jpeg
    ```
* **Generated Image Directory (Optional):** The `generate_dalle_images.py` script saves images to the directory you specify via `--output-dir`. You can then use this directory as one of the inputs for the YOLO data generation step.
* **YOLO Dataset Output Directory:** The `generate_yolo_data.py` script creates this directory (specified via `--output-dir`). It will contain the final dataset:
    ```
    <yolo_output_dir>/
    ├── data.yaml
    ├── images/
    │   ├── train/
    │   ├── val/
    │   └── test/
    └── labels/
        ├── train/
        ├── val/
        └── test/
    ```
* **Visualization Output Directory:** The `draw_yolo_boxes.py` script creates this directory (specified via `--output-dir`) to store images with bounding boxes drawn on them.

## Running the Pipeline

Make sure your virtual environment is activated (`source .venv/bin/activate`) before running these commands.

**Step 1: Generate Source Images (Optional)**

If you need to generate images using DALL-E 3, use the `generate_dalle_images.py` script. Run it separately for each category you need.

* Generate 10 flip-flop images into a directory named `source_flipflops`:
    ```bash
    python generate_dalle_images.py --category flip-flops --num-images 10 --output-dir source_flipflops
    ```
* Generate 10 boot images into `source_boots`:
    ```bash
    python generate_dalle_images.py --category boots --num-images 10 --output-dir source_boots
    ```
* Generate 10 helmet/glove images into `source_helmet_glove`:
    ```bash
    python generate_dalle_images.py --category helmet-glove --num-images 10 --output-dir source_helmet_glove
    ```
    *(Adjust `--num-images`, `--output-dir`, `--size`, `--quality` as needed).*

**Step 2: Generate YOLO Dataset**

Use the `generate_yolo_data.py` script to process your source images (either generated or provided by you) and create the YOLO formatted dataset. This script uses PaliGemma for automatic annotation.

* Provide the directories containing your source images using `--input-dirs`.
* Specify the desired output directory name using `--output-dir`.
* Use `--require-both` for directories where specific multiple objects *must* be detected (like helmet and glove).

```bash
python generate_yolo_data.py \
    --input-dirs source_flipflops source_boots source_helmet_glove \
    --output-dir yolo_ppe_dataset \
    --require-both helmet-glove helmet glove
```
*(Replace `source_flipflops`, `source_boots`, `source_helmet_glove` with the actual paths to your image directories. Replace `yolo_ppe_dataset` with your desired output name.)*

This script will:

* Load the PaliGemma model (this might take time on the first run).
* Scan the input directories.
* Perform stratified splitting into train/val/test sets.
* Process each image: detect objects, convert to YOLO format, write label files.
* **Copy** images to the output directory structure (`yolo_ppe_dataset/images/...`).
* Create the `yolo_ppe_dataset/data.yaml` file.
* Print warnings if target objects aren't found or required objects are missing.
* The script is idempotent – it skips images if the corresponding label file already exists in the output directory.

**Step 3: Visualize Annotations (Verification)**

After generating the dataset, use `draw_yolo_boxes.py` to create visual copies of the images with the generated bounding boxes drawn on them. This helps verify the quality of the automatic annotations.

* Provide the path to the generated YOLO dataset directory using `--dataset-dir`.
* Specify an output directory for the visualized images using `--output-dir`.

```bash
python draw_yolo_boxes.py \
    --dataset-dir yolo_ppe_dataset \
    --output-dir yolo_ppe_dataset_visualized
```

*(Replace `yolo_ppe_dataset` with the actual name of your generated dataset directory.)*

This will create a new directory (e.g., `yolo_ppe_dataset_visualized`) containing `train`, `val`, and `test` subdirectories with images that have red bounding boxes and class labels drawn on them. Review these images to ensure the PaliGemma detections and YOLO conversions are accurate.

## Script Explanations

* **`generate_dalle_images.py`**: Uses the OpenAI API (DALL-E 3) to generate new images based on predefined text prompts for different categories. Saves images to a specified directory.
* **`paligemma_detector.py`**: A module containing functions to load the PaliGemma model and perform object detection on a given image, returning detected object labels and their normalized bounding boxes. This is used internally by `generate_yolo_data.py`.
* **`generate_yolo_data.py`**: The main script for creating the YOLO dataset. It orchestrates finding source images, calling the PaliGemma detector, converting annotations to YOLO format, performing a stratified train/val/test split, copying images, and creating the `data.yaml` file.
* **`draw_yolo_boxes.py`**: A utility script to read a generated YOLO dataset and produce visualized images with bounding boxes and labels drawn, useful for verification.