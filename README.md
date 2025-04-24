# ImageToFormPOC - Lightweight On-Device AI for Field Service

Copyright © 2025 Toni Melisma

## Project Overview

This project is a prototype iOS application demonstrating how lightweight, on-device Artificial Intelligence (AI) capabilities, specifically computer vision, can enhance field service workflows, even on potentially older iPhone hardware. The goal is to showcase practical use cases where image analysis can automate or simplify common tasks performed by field technicians, reducing manual data entry and improving accuracy.

The application leverages Apple's native frameworks:

* **SwiftUI:** For building the user interface.
* **Vision:** For Optical Character Recognition (OCR) and interacting with Core ML models.
* **Core ML:** For running the custom object detection model directly on the device.

This on-device approach ensures functionality even without a network connection and keeps potentially sensitive image data localized to the user's device.

## Application Flow

The application presents a main menu with three core proof-of-concept features:

1.  **Verify Protective Gear:**
    * The user is prompted to take photos (selfie for helmet/gloves, rear camera for boots).
    * A Core ML object detection model (`best.mlpackage`) runs on the captured image to identify required Personal Protective Equipment (PPE) like helmets, gloves, and boots.
    * It specifically checks for unsafe footwear like flip-flops.
    * The user reviews the detection results (image with bounding boxes) before the checklist is updated.

2.  **Read Meter:**
    * The user takes a photo of a physical meter using the rear camera.
    * The Vision framework performs OCR on the image to detect numerical strings.
    * The app attempts to intelligently pre-select the most likely reading (based on proximity to 10,000 in this prototype).
    * The user reviews the detected numbers, selects the correct one if needed, and confirms the reading.

3.  **Capture Equipment Info:**
    * The user takes a photo of an equipment label (e.g., a nameplate on an HVAC unit).
    * The Vision framework performs OCR to extract all text from the label.
    * The user can optionally preview the raw OCR results with bounding boxes.
    * The app attempts an initial automatic parse using regular expressions and keyword matching to identify common fields (Mfg Date, Voltage, Amps, Pressure, Model, Serial Number).
    * The user reviews these automatically parsed values.
    * If any key fields remain empty, the user is guided through assigning the remaining unrecognized OCR text snippets to the appropriate form fields.
    * Once all required information is gathered (either automatically or manually assigned), the user can confirm.

## Requirements

* Xcode 16.0 or later (due to iOS 18 SDK usage for some Vision/Core ML APIs)
* iOS 18.0 or later target device (Recommended: Physical device for camera and Core ML testing)
* Swift 5.10 or later

## Core ML Model Dependency

This project requires a custom Core ML object detection model for the "Verify Protective Gear" feature.

* **Model File:** `best.mlpackage`
* **Reason for External Download:** Due to potential licensing restrictions or file size, the model file is not included directly in this repository.
* **Download Link:** You can download the required model file from:
    [https://drive.google.com/open?id=1h3-loDtefg1d-dLe-NyMns2Rwme0Kkiz&usp=drive_fs](https://drive.google.com/open?id=1h3-loDtefg1d-dLe-NyMns2Rwme0Kkiz&usp=drive_fs)

## Model Training Details

The `best.mlpackage` Core ML model used in this application was trained using a specific pipeline involving synthetic data generation (DALL-E 3), automated annotation (PaliGemma), and YOLOv11-style training.

For detailed information on the dataset generation process, training procedure, and the scripts involved, please refer to the README located in the `model_training` subdirectory:

[**`model_training/README.md`**](./model_training/README.md)

*(Note: Requires separate setup and dependencies as outlined in that README).*

## Installation and Running

1.  **Clone the Repository:**
    ```bash
    git clone <repository-url>
    cd ImageToFormPOC
    ```
2.  **Download the Core ML Model:** Download the `best.mlpackage` file from the Google Drive link provided above.
3.  **Add Model to Project:**
    * Open the `ImageToFormPOC.xcodeproj` file in Xcode.
    * Drag the downloaded `best.mlpackage` file directly into the Xcode Project Navigator (the left-hand file list).
    * When prompted, ensure "Copy items if needed" is checked and that the target "ImageToFormPOC" is selected. Verify that the model file appears in the "Copy Bundle Resources" phase within the project's Build Phases settings.
4.  **Build and Run:**
    * Select a target device (physical device recommended for full functionality) or simulator.
    * Build and run the project (Product > Run or Cmd+R).
    * If running on a device, you may need to configure code signing with your Apple Developer account.
    * Grant camera and photo library permissions when prompted by the app.

**Note:** While the app may run on the simulator, features requiring the camera or specific Core ML hardware acceleration will be limited or unavailable.

## License

Copyright © 2025 Toni Melisma. All rights reserved. (Or refer to a separate LICENSE file if one exists).

