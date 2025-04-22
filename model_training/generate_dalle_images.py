import os
import argparse
import time
import uuid
from pathlib import Path
import requests
from PIL import Image
from io import BytesIO
import openai
from dotenv import load_dotenv

# --- Configuration ---

# Define the prompts for each category
PROMPTS = {
    "flip-flops": "A person standing on a concrete sidewalk wearing red flip-flops. Their legs are visible from mid-calf down, with light skin and some visible leg hair. The person's feet are relaxed, with slightly uneven toenails, and the right big toenail appears thickened or slightly damaged. The setting appears to be outdoors, possibly a porch or entrance area, with some mulch and greenery just beyond the concrete edge. The lighting is natural, suggesting early evening or late afternoon.",
    "boots": "A person standing on a smooth, light-colored concrete surface wearing modern, minimalist slip-on clogs. The clogs are matte navy blue with off-white rubber soles. Their pants are olive green. The lighting is bright and clean, suggesting daytime with clear shadows, possibly late morning or early afternoon. The overall aesthetic is clean, casual, and slightly urban with a Scandinavian or minimalist vibe.",
    "helmet-glove": "A cheerful man smiling brightly in an outdoor suburban setting during the daytime, standing in front of a white house with horizontal siding and a dark shingle roof. He is wearing a matte white bicycle or skate-style helmet and a light gray polo shirt. On his right hand, he is wearing a solid black glove with an elastic cuff, and he is raising that hand in a friendly wave toward the camera. The background includes a green lawn and neatly trimmed bushes, and the lighting is warm and sunny, creating soft shadows that suggest late afternoon."
}

# DALL-E 3 supported sizes
VALID_SIZES = ["1024x1024", "1024x1792", "1792x1024"]
# DALL-E 3 supported qualities
VALID_QUALITIES = ["standard", "hd"]

def download_and_save_image(image_url, output_dir, category, index):
    """Downloads an image from a URL and saves it."""
    try:
        response = requests.get(image_url, stream=True, timeout=60) # Add timeout
        response.raise_for_status() # Raise an exception for bad status codes

        # Generate a unique filename
        # timestamp = int(time.time())
        unique_id = str(uuid.uuid4())[:8] # Short unique ID
        filename = f"{category}_{index:03d}_{unique_id}.png"
        output_path = output_dir / filename

        # Save the image using Pillow to ensure format consistency (PNG)
        img = Image.open(BytesIO(response.content))
        img.save(output_path, "PNG")
        print(f"Successfully saved image: {output_path}")
        return True

    except requests.exceptions.RequestException as e:
        print(f"Error downloading image from {image_url}: {e}")
        return False
    except IOError as e:
        print(f"Error saving image {filename}: {e}")
        return False
    except Exception as e:
         print(f"An unexpected error occurred during download/save: {e}")
         return False


def main(category, num_images, output_dir, size, quality):
    """Generates images using DALL-E 3 based on the specified category."""

    # --- 1. Load API Key ---
    load_dotenv()
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        print("Error: OPENAI_API_KEY not found.")
        print("Please create a .env file with OPENAI_API_KEY='your_key_here'")
        return

    try:
        client = openai.OpenAI(api_key=api_key)
    except Exception as e:
        print(f"Error initializing OpenAI client: {e}")
        return

    # --- 2. Validate Inputs ---
    if category not in PROMPTS:
        print(f"Error: Invalid category '{category}'. Valid categories are: {list(PROMPTS.keys())}")
        return
    if size not in VALID_SIZES:
        print(f"Error: Invalid size '{size}'. Valid sizes for DALL-E 3 are: {VALID_SIZES}")
        return
    if quality not in VALID_QUALITIES:
         print(f"Error: Invalid quality '{quality}'. Valid qualities are: {VALID_QUALITIES}")
         return

    selected_prompt = PROMPTS[category]
    output_path = Path(output_dir)

    # Create output directory if it doesn't exist
    output_path.mkdir(parents=True, exist_ok=True)
    print(f"Saving generated images to: {output_path.resolve()}")

    # --- 3. Generate Images ---
    print(f"Generating {num_images} image(s) for category '{category}'...")
    successful_generations = 0
    for i in range(num_images):
        print(f"\nGenerating image {i+1}/{num_images}...")
        try:
            response = client.images.generate(
                model="dall-e-3",
                prompt=selected_prompt,
                size=size,
                quality=quality,
                n=1, # DALL-E 3 only supports n=1
                response_format="url" # Get URL to download
            )

            # DALL-E 3 returns one image url in the data list
            if response.data and response.data[0].url:
                image_url = response.data[0].url
                revised_prompt = response.data[0].revised_prompt
                print(f"  Image URL received.")
                # Optional: print revised prompt
                # print(f"  Revised Prompt: {revised_prompt}")

                # Download and save the image
                if download_and_save_image(image_url, output_path, category, i + 1):
                    successful_generations += 1
                else:
                    print(f"  Failed to download/save image {i+1}.")

                # Add a small delay between requests as a courtesy/precaution
                if num_images > 1 and i < num_images - 1:
                    time.sleep(2)

            else:
                print(f"Error: No image URL found in API response for image {i+1}.")
                print(f"  Response: {response}")


        except openai.OpenAIError as e:
            print(f"An OpenAI API error occurred for image {i+1}: {e}")
            if hasattr(e, 'http_status'): print(f"  HTTP Status: {e.http_status}")
            if hasattr(e, 'error'): print(f"  Error details: {e.error}")
            # Consider adding retry logic here if needed
        except Exception as e:
            print(f"An unexpected error occurred during generation for image {i+1}: {e}")

    print(f"\nGeneration complete. Successfully generated and saved {successful_generations}/{num_images} images.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate images using OpenAI DALL-E 3 API.")
    parser.add_argument(
        '--category',
        type=str,
        required=True,
        choices=list(PROMPTS.keys()),
        help='The category of image to generate.'
    )
    parser.add_argument(
        '--num-images',
        type=int,
        default=1,
        help='Number of images to generate for the category.'
    )
    parser.add_argument(
        '--output-dir',
        type=str,
        required=True,
        help='Directory where the generated images will be saved.'
    )
    parser.add_argument(
        '--size',
        type=str,
        default="1024x1024",
        choices=VALID_SIZES,
        help=f'Size of the generated images. Default: 1024x1024.'
    )
    parser.add_argument(
        '--quality',
        type=str,
        default="standard",
        choices=VALID_QUALITIES,
        help='Quality of the generated images. Default: standard.'
    )

    args = parser.parse_args()
    main(args.category, args.num_images, args.output_dir, args.size, args.quality)
