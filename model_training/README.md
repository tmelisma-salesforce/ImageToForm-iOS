# YOLO Object Detection Dataset Generation Pipeline

This project provides a pipeline to generate images using DALL-E 3, automatically annotate them for object detection using PaliGemma, format the results into a YOLO-compatible dataset, train a YOLOv11-style model, and export it for deployment (e.g., Core ML). It also includes a script to visualize the generated annotations for verification.

**Target Classes:** flip-flops, helmet, glove, boots

## Prerequisites

* Python 3.8 or higher
* `pip` (Python package installer)
* An OpenAI API Key (for DALL-E 3 image generation)
* A Weights & Biases account (optional, for experiment tracking) - [https://wandb.ai/](https://wandb.ai/)

## Setup

1.  **Clone the Repository (if applicable):**
    If this project is in a Git repository, clone it first:
    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```
    Otherwise, ensure all the scripts (`generate_dalle_images.py`, `paligemma_detector.py`, `generate_yolo_data.py`, `draw_yolo_boxes.py`, `predict_image.py`) are in the same directory.

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
    Install the required Python libraries, including Ultralytics (for YOLO training/export) and Weights & Biases (for logging):
    ```bash
    pip install ultralytics wandb openai python-dotenv requests Pillow torch torchvision PyYAML tqdm accelerate bitsandbytes
    ```
    *(Note: `bitsandbytes` and `accelerate` help with model loading and memory efficiency, especially on GPUs/MPS).*

4.  **Create `.env` File:**
    Create a file named `.env` in the root directory of the project and add your OpenAI API key:
    ```
    OPENAI_API_KEY='your_openai_api_key_here'
    ```
    Replace `your_openai_api_key_here` with your actual secret key. **Do not commit this file to version control.**

5.  **Log in to Weights & Biases (Optional):**
    If you want to track your experiments, log in to W&B:
    ```bash
    wandb login
    ```
    Follow the prompts (you'll likely need to paste an API key from your W&B account settings).
    You might also need to explicitly enable W&B integration for the `yolo` CLI (run this once):
    ```bash
    yolo settings wandb=True
    ```

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
* **Training Runs Directory:** The YOLO training script automatically creates a directory (usually `runs/detect/`) to save results for each run (logs, weights, plots).
* **Visualization Output Directory:** The `draw_yolo_boxes.py` script creates this directory (specified via `--output-dir`) to store images with bounding boxes drawn on them.

## Running the Pipeline

Make sure your virtual environment is activated (`source .venv/bin/activate`) before running these commands.

**Step 1: Generate Source Images (Optional)**

Use `generate_dalle_images.py` if you need to create images via DALL-E 3.

```bash
# Example: Generate 10 helmet/glove images into source_helmet_glove
python generate_dalle_images.py --category helmet-glove --num-images 10 --output-dir source_helmet_glove
```

*(Adjust `--num-images`, `--output-dir`, `--size`, `--quality` as needed).*

**Step 2: Generate YOLO Dataset**

Use `generate_yolo_data.py` to process source images and create the YOLO formatted dataset. This script uses PaliGemma for automatic annotation.

* Provide the directories containing your source images using `--input-dirs`.
* Specify the desired output directory name using `--output-dir`.
* Use `--require-both` for directories where specific multiple objects *must* be detected (like helmet and glove).

```bash
# Example: Process images from 3 source dirs, output to yolo_ppe_dataset, require helmet & glove in helmet-glove dir
python generate_yolo_data.py \
    --input-dirs source_flipflops source_boots source_helmet_glove \
    --output-dir yolo_ppe_dataset \
    --require-both helmet-glove helmet glove
```
*(Replace source directories and output directory name as needed.)*

**Step 3: Visualize Annotations (Verification)**

Use `draw_yolo_boxes.py` to visually check the *ground truth* labels generated in Step 2 **before** training. This helps verify the quality of the automatic annotations.

```bash
python draw_yolo_boxes.py \
    --dataset-dir yolo_ppe_dataset \
    --output-dir yolo_ppe_dataset_visualized
```

*(Review the images created in `yolo_ppe_dataset_visualized`.)*

**Step 4: Train YOLO Model**

Use the `yolo` command (from the Ultralytics library) to train a model on your verified generated dataset.

* **Choose a Model:** Start with a smaller pre-trained model like `yolo11n.pt` or `yolo11s.pt`.
* **Set `patience`:** Use early stopping (e.g., `patience=20` or `patience=50`) to stop training automatically when validation metrics stop improving. Set `epochs` to a high number (e.g., `epochs=300`).
* **Specify Device:** Use `device=mps` for Apple Silicon.
* **W&B Logging:** If logged in and enabled, logging should start automatically.

```bash
# Example: Train the 'small' model with patience
yolo detect train \
    data=yolo_ppe_dataset/data.yaml \
    model=yolo11s.pt \
    epochs=300 \
    patience=50 \
    imgsz=640 \
    batch=8 \
    device=mps \
    name=small_run_p50 \
    project=PPE_Detection
```
*(Adjust `model`, `batch`, `name`, `patience`, `epochs` as needed. Ensure `data=` points to your `data.yaml` file.)*

* **Monitoring:** Watch validation metrics (`mAP50-95`) in the terminal or on W&B. Training stops based on `patience`.
* **Resuming:** If interrupted (`Ctrl+C`), resume using `last.pt`:
  ```bash
  yolo detect train resume model=runs/detect/small_run_p50/weights/last.pt
  ```

  **Step 5: Export Trained Model (for Deployment)**

Once training is complete and you're satisfied with the `best.pt` model, export it to your desired format (e.g., Core ML). Include NMS.

```bash
# Example: Export the best model from the 'small_run_p50' run to Core ML
yolo export \
    model=runs/detect/small_run_p50/weights/best.pt \
    format=coreml \
    nms=True
```

*(This creates a `.mlpackage` or `.mlmodel` file.)*

**Step 6: Test Model Predictions (Optional but Recommended)**

Use `predict_image.py` (or `yolo predict`) with your exported `best.pt` model to see how it performs on individual test images and visualize its predictions.

```bash
# Example using the script
python predict_image.py \
    --model runs/detect/small_run_p50/weights/best.pt \
    --image yolo_ppe_dataset/images/test/some_test_image.png \
    --output-dir test_predictions \
    --data-yaml yolo_ppe_dataset/data.yaml

# Example using the CLI (creates output in runs/detect/predict*)
# yolo predict model=runs/detect/small_run_p50/weights/best.pt source=yolo_ppe_dataset/images/test/some_test_image.png device=mps save=True
```

## Script Explanations

* **`generate_dalle_images.py`**: Uses OpenAI API (DALL-E 3) to generate new images.
* **`paligemma_detector.py`**: Module used by the generator script to detect objects using PaliGemma.
* **`generate_yolo_data.py`**: Creates the YOLO dataset (images/labels/yaml) using PaliGemma for annotation and performs stratified splitting. Enforces labels based on source directory structure.
* **`draw_yolo_boxes.py`**: Visualizes the *ground truth* annotations from a generated YOLO dataset.
* **`predict_image.py`**: Runs inference with a trained YOLO model on a single image and saves a visualized output showing the *model's predictions*.
* **`yolo` command (Ultralytics)**: Used for training (`train`), exporting (`export`), and prediction (`predict`).