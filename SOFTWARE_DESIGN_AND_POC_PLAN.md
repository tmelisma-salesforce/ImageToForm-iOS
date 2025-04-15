# Software Design Document & POC Implementation Plan: ImageToForm-iOS

**Document Version:** 2.0 (Revised for Enhanced Clarity)
**Date:** April 14, 2025
**Project:** ImageToForm-iOS Proof of Concept

**Purpose:** This document outlines the software architecture and detailed design for the ImageToForm-iOS application's full vision. It also provides a step-by-step requirements breakdown and technical implementation guide for building the initial Proof of Concept (POC), intended for developers, including junior engineers requiring highly explicit instructions.

---

## Part 1: Software Architecture Outline (Full Vision)

This section describes the high-level structure and components envisioned for the *complete*, robust application designed for on-device form filling from images.

**1.1. Goal:**
To create a modular, efficient, and reliable on-device system for extracting structured data from images (like insurance cards, labels) and automatically populating mobile application forms, minimizing user effort and errors.

**1.2. Key Architectural Principles:**
* **On-Device Processing:** All sensitive operations, including image analysis and text recognition, occur locally on the user's device. This ensures user privacy and enables offline functionality.
* **Modularity & Separation of Concerns:** The system is divided into distinct components (layers or services) with well-defined responsibilities. This promotes maintainability, testability, and independent development or replacement of parts.
* **User-Centric Design:** The system prioritizes a smooth user experience through clear guidance during capture and absolute user control over reviewing and confirming extracted data. Accuracy is crucial, but user validation is paramount.
* **Asynchronous Operations:** computationally intensive tasks (image processing, ML inference) are performed off the main thread to keep the user interface responsive.

**1.3. Major Architectural Components:**

1.  **Presentation Layer (UI):**
    * **Responsibility:** Renders the user interface, including forms, camera views, instructional overlays, progress indicators, and final results. Captures user interactions like button taps, photo capture actions, and data corrections.
    * **Sub-components:** Views (e.g., `FormView`, `CameraView`), ViewModels (managing UI state and logic, potentially using MVVM), UI Controls.
2.  **Application Logic & Coordination Layer:**
    * **Responsibility:** Acts as the central orchestrator. Manages application state, routes user requests to appropriate services, coordinates the data flow between layers, handles context (knowing *what* type of document is being scanned), and manages error propagation.
    * **Sub-components:** Coordinators, Managers (e.g., `ScanSessionManager`), State Management system.
3.  **Capture & Preprocessing Service:**
    * **Responsibility:** Manages all interactions with the device camera hardware via system frameworks (`AVFoundation`). Provides image buffers from the camera feed. Captures high-resolution still images. Performs essential image preparation steps before analysis (cropping, perspective correction/deskewing, rotation correction, brightness/contrast enhancement). Optionally provides real-time image quality analysis during preview.
    * **Sub-components:** Camera Session Manager, Image Buffer Provider, Image Preprocessor Pipeline (using `Core Image`, `vImage`).
4.  **Core Extraction Service:**
    * **Responsibility:** Executes the core Machine Learning tasks. Interfaces with Apple's `Vision` and `Core ML` frameworks. Manages the loading and execution of ML models (both built-in Apple models for tasks like OCR and potentially custom/external models for object detection). Performs Text Recognition (OCR) and optionally Object Detection.
    * **Sub-components:** Vision Request Handler, OCR Processor, Object Detection Processor (optional), Model Provider.
5.  **Parsing & Validation Service:**
    * **Responsibility:** Transforms the raw text output from the OCR engine into meaningful, structured data. Applies parsing rules (keywords, Regular Expressions, positional logic) based on the context provided by the Coordination Layer. Validates the extracted data against expected formats and constraints (e.g., date validity, checksums).
    * **Sub-components:** Parsing Rule Engine, Data Validation Module, Contextual Rule Selector.

**1.4. High-Level Data and Control Flow:**

The typical flow involves the UI Layer initiating a scan request via the Coordination Layer. The Coordinator activates the Capture Service, which provides a processed image buffer. This buffer is passed to the Core Extraction Service for OCR. The resulting raw text, along with context, goes to the Parsing & Validation Service. The structured, validated data (or errors) are returned via the Coordinator to the Presentation Layer, which updates the form fields or displays appropriate messages, always allowing user review. Asynchronous operations with completion handlers, delegates, or reactive patterns (like Combine) manage the flow between background processing and main thread UI updates. The system is designed such that components interact through well-defined interfaces, promoting decoupling.

---

## Part 2: Detailed Design Document (Full Vision)

This section provides more specific design details for the components outlined in the architecture for the *complete* system.

**2.1. Presentation Layer:**
* **UI Framework:** SwiftUI is recommended for leveraging modern declarative UI, state management, and integration features. UIKit remains a viable alternative.
* **Design Pattern:** Model-View-ViewModel (MVVM) provides a good separation of concerns.
    * **Views:** SwiftUI Views (`struct` conforming to `View`). Minimal logic, primarily layout and data binding. Examples: `FormView`, `LiveCameraView` (wrapping AVFoundation), `ScanResultsView`.
    * **ViewModels:** `ObservableObject` classes. Hold UI state (`@Published` properties). Contain presentation logic. Expose functions for Views to call (e.g., `startScan()`, `confirmData()`). Interact with the Coordination Layer or Services.
    * **Models:** Simple `struct`s representing data (e.g., `FormField`, `ScanResultData`).
* **Key Technologies:** SwiftUI, Combine (for reactive updates), potentially `UIViewRepresentable` or `UIViewControllerRepresentable` to integrate UIKit components like `AVCaptureVideoPreviewLayer`.

**2.2. Application Logic & Coordination Layer:**
* **Responsibilities:** Manage scan sessions, maintain overall application state, handle navigation related to scanning, translate service responses/errors into ViewModel updates.
* **Key Technologies:** Swift Standard Library, Combine (for managing asynchronous flows), potentially Dependency Injection frameworks/patterns. Use Swift Concurrency (`async/await`, `Task`, `@MainActor`) for managing threading.

**2.3. Capture & Preprocessing Service:**
* **Camera Management:** Encapsulate `AVFoundation` objects (`AVCaptureSession`, `AVCaptureDevice`, `AVCaptureDeviceInput`, `AVCapturePhotoOutput`, `AVCaptureVideoDataOutput`) within a dedicated class (e.g., `CameraService`). Use delegate patterns (`AVCapturePhotoCaptureDelegate`, `AVCaptureVideoDataOutputSampleBufferDelegate`) to receive outputs. Manage session setup, start/stop, and camera permissions.
* **Image Representation:** Work with `CMSampleBuffer` (from video output), `CVPixelBuffer`, `UIImage`, `CGImage`, `CIImage` as appropriate for different stages. Ensure efficient conversions.
* **Preprocessing Pipeline:** Define a clear sequence of operations within an `ImagePreprocessor` class or similar. Use `Vision` (`VNDetectRectanglesRequest`) for detecting document boundaries/corners. Use `Core Image` (`CIFilter` like `CIPerspectiveCorrection`, `CIColorControls`) and/or Apple's `Accelerate` framework (`vImage` functions) for efficient cropping, deskewing, and enhancement (e.g., contrast stretching, thresholding). Perform these operations on background threads.

**2.4. Core Extraction Service:**
* **Primary Tool:** Apple `Vision` framework.
* **Text Recognition:** Utilize `VNRecognizeTextRequest`. Configure properties like `recognitionLevel` (`.accurate` preferred for stills), `usesLanguageCorrection`, potentially `customWords` if common non-dictionary terms are expected (like specific medical terms).
* **Object Detection (Optional):** If specific object detection (beyond simple rectangles) is needed, use `VNCoreMLRequest` with a suitable `.mlmodel` file. The model itself needs to be sourced (pre-trained if available and suitable, or custom-trained). Model management involves bundling or using Core ML's deployment features.
* **Error Handling:** Catch errors thrown by `VNImageRequestHandler.perform()` and handle errors passed to `VNRequest` completion handlers.

**2.5. Parsing & Validation Service:**
* **Rule Definition:** Define rules clearly. Consider loading rules from a configuration file (JSON, Plist) for easier updates without recompiling the app. Associate rules with specific document contexts. Example Rule Structure: `{ "context": "InsuranceCard_TypeA", "rules": [ { "fieldName": "memberId", "regex": "W[A-Z]{2}\\d{9}", "keywords": ["Member ID:", "ID No."] }, ... ] }`.
* **Parsing Logic:** Implement a `Parser` class that takes OCR results (array of strings or `VNRecognizedTextObservation`s) and context. Apply relevant rules using `NSRegularExpression` and string searching logic. Handle ambiguity (e.g., multiple regex matches).
* **Validation Logic:** Implement a `Validator` class or functions. Include checks for format (dates via `DateFormatter`), length, checksums (Luhn algorithm for credit cards/some IDs), consistency, etc.
* **Output:** Return a well-defined structure, perhaps a dictionary `[String: Result<String, ValidationError>]`, indicating success or specific validation errors for each targeted field.

**2.6. Threading Model:**
* UI Interactions: Must occur on the **Main Thread**.
* Camera Feed Handling (`AVCaptureVideoDataOutputSampleBufferDelegate`): Delivered on a specific queue; dispatch any significant processing (real-time analysis) to a background queue.
* Image Preprocessing, Vision/Core ML Inference, Parsing, Validation: Must occur on **Background Threads** to avoid blocking the UI. Use `DispatchQueue.global()` or Swift Concurrency (`Task { ... }`).
* Result Handling: Deliver final results or errors back to the **Main Thread** for UI updates using `DispatchQueue.main.async { ... }` or `@MainActor`.

---

## Part 3: Proof of Concept (POC) - Detailed Implementation Plan (Enhanced Clarity)

This section provides a step-by-step guide for building the minimal POC, with highly explicit instructions suitable for a junior developer or someone needing very clear guidance. Each step builds directly on the previous one.

**Goal:** Validate core on-device text detection and OCR using Apple's Vision framework on a single captured image, displaying the raw text results and visual bounding box feedback.

**Technology:** Swift, SwiftUI, Vision, UIImagePickerController.

---

### Step 0: Project Setup

* **0.A: Functional Requirements:**
    * FR0.1: Create a new, runnable iOS application project in Xcode.
    * FR0.2: Configure the project with basic necessary settings (Bundle ID, Privacy Description).
    * FR0.3: Set up Git version control with appropriate ignored files.
* **0.B: Non-Functional Requirements:**
    * NFR0.1: The project must use Swift as the language and SwiftUI as the Interface/Life Cycle.
    * NFR0.2: The project must target a reasonably modern iOS version (e.g., iOS 15.0+) to ensure Vision framework support.
    * NFR0.3: The project must include the necessary privacy key for camera usage in its configuration file.
* **0.C: Technical Design & Implementation:**
    1.  **Create Project:** Open Xcode. Select File -> New -> Project. Choose the "iOS" tab and select the "App" template. Click Next.
    2.  **Project Options:**
        * Product Name: `ImageToFormPOC`
        * Team: (Select your development team if applicable)
        * Organization Identifier: Enter your unique identifier (e.g., `com.yourcompanyname` or `io.github.yourusername`). Xcode uses this to create the Bundle Identifier.
        * Interface: Select `SwiftUI`.
        * Life Cycle: Select `SwiftUI App`.
        * Language: Select `Swift`.
        * Uncheck "Use Core Data". Uncheck "Include Tests" (you can add tests later). Click Next.
    3.  **Save Project:** Choose a location on your computer to save the project. Make sure the "Create Git repository on my Mac" checkbox is checked. Click Create.
    4.  **Set Deployment Target:** In the Project Navigator (left panel), click the top blue project icon (`ImageToFormPOC`). Select the `ImageToFormPOC` target under "TARGETS". Go to the "General" tab. Under "Deployment Info", set the "iOS" version dropdown to `15.0` (or a later version if preferred).
    5.  **Add Privacy Description:** Go to the "Info" tab for the `ImageToFormPOC` target. Under "Custom iOS Target Properties", hover over the last row and click the (+) button that appears. From the dropdown list, select "Privacy - Camera Usage Description". In the "Value" column next to it, type a clear reason for needing the camera, for example: `This app needs access to the camera to scan documents and extract text.` Xcode saves this automatically.
    6.  **Configure Gitignore:** Open a text editor (like TextEdit or VSCode). Copy the entire `.gitignore` content provided in the previous response (the standard Swift/Xcode template). Save this file *exactly* as `.gitignore` (note the leading dot, no `.txt` extension) in the main folder of your project (the folder containing the `.xcodeproj` file). In your terminal, navigate to this project folder and commit these initial files:
        ```bash
        git add .
        git commit -m "Initial project setup with settings and gitignore"
        ```
    7.  **Verification:** Build and run the app (Cmd+R) on a Simulator or a connected physical device. It should launch showing the default "Hello, World!" SwiftUI template without errors. Stop the app.

---

### Step 1: Basic UI Layout

* **1.A: Functional Requirements:**
    * FR1.1: Display the title "POC Scanner".
    * FR1.2: Display a button labeled "Scan Document".
    * FR1.3: Display a placeholder area where the captured image will appear later.
    * FR1.4: Display a placeholder area where the extracted text results will appear later.
* **1.B: Non-Functional Requirements:**
    * NFR1.1: The UI must be built using SwiftUI.
    * NFR1.2: The layout should vertically stack the title, image area, text area, and button.
    * NFR1.3: The UI must use `@State` variables to manage the data that will change (captured image, Vision results, and the state controlling the camera presentation).
* **1.C: Technical Design & Implementation:**
    1.  **Open ContentView:** In Xcode's Project Navigator, find and open the `ContentView.swift` file.
    2.  **Import Vision:** Add `import Vision` at the top of the file, below `import SwiftUI`. We will need types from Vision later.
    3.  **Declare State Variables:** Inside the `struct ContentView: View { ... }` definition, *before* the `var body: some View { ... }` line, add these `@State` variables:
        ```swift
        @State private var capturedImage: UIImage? = nil // Holds the photo taken by the user
        @State private var visionResults: [VNRecognizedTextObservation] = [] // Holds results from Vision
        @State private var showingImagePicker = false // Controls showing the camera
        ```
    4.  **Structure the Body:** Replace the default `VStack { Image(...); Text("Hello, world!") }` inside `var body: some View { ... }` with the following structure:
        ```swift
        NavigationView { // Use NavigationView to easily add a title bar
            VStack { // Main vertical layout
                // Placeholder for Image and Overlay (Step 6)
                ZStack {
                    if let image = capturedImage {
                        // We will display the actual image here later
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            // Overlay will be added here in Step 6
                    } else {
                        // Placeholder when no image is captured yet
                        Text("Capture an image to see results.")
                            .padding()
                            .foregroundColor(.gray)
                    }
                }
                .frame(minHeight: 200, maxHeight: 400) // Define visual size for the image area
                .border(Color.gray, width: 1) // Show border for the image area
                .padding([.leading, .trailing, .bottom]) // Add some spacing

                // Placeholder for Text Results (Step 5)
                List {
                    Section("Extracted Text:") {
                        // Text results will be shown here later
                        Text("Scan an image to view extracted text.")
                           .foregroundColor(.gray)
                    }
                }
                // Make the List take up available space dynamically
                .listStyle(InsetGroupedListStyle()) // Optional styling

                Spacer() // Pushes the button towards the bottom

                // The button to start scanning
                Button("Scan Document") {
                    // Action: Set the state variable to true to show the camera sheet
                    self.showingImagePicker = true
                }
                .padding() // Add padding around the button
                .buttonStyle(.borderedProminent) // Make the button look prominent

            } // End of main VStack
            .navigationTitle("POC Scanner") // Set the title in the navigation bar
            .navigationBarTitleDisplayMode(.inline) // Style the title
            // Add the .sheet modifier to present the Image Picker (Step 2)
            .sheet(isPresented: $showingImagePicker) {
                // The content here will be the ImagePicker view created next
                // For now, add a placeholder Text view:
                Text("Image Picker will go here")
            }
        } // End of NavigationView
        ```
    5.  **Verification:** Build and run the app (Cmd+R). You should see:
        * A navigation bar with the title "POC Scanner".
        * An empty gray-bordered rectangle with the text "Capture an image...".
        * A list area below it with the text "Scan an image...".
        * A prominent "Scan Document" button at the bottom.
        * Tapping the button should present a temporary sheet saying "Image Picker will go here". Dismiss the sheet manually for now. Stop the app.

---

### Step 2: Implement Image Capture Functionality

* **2.A: Functional Requirements:**
    * FR2.1: Tapping "Scan Document" presents the live camera view (or photo library if camera unavailable).
    * FR2.2: The user can capture/select a photo or cancel.
    * FR2.3: If a photo is confirmed, the app receives it as a `UIImage`.
    * FR2.4: The camera/picker view dismisses automatically after user action (confirm or cancel).
* **2.B: Non-Functional Requirements:**
    * NFR2.1: Use `UIImagePickerController` wrapped in `UIViewControllerRepresentable` for SwiftUI integration.
    * NFR2.2: Implement required delegate protocols (`UINavigationControllerDelegate`, `UIImagePickerControllerDelegate`).
    * NFR2.3: Pass the captured `UIImage` back to `ContentView` using `@Binding`.
    * NFR2.4: Dismiss the view controller correctly using `presentationMode`.
* **2.C: Technical Design & Implementation:**
    1.  **Create New File:** In Xcode, go to File -> New -> File... Select "Swift File" under the iOS tab. Click Next. Name the file `ImagePicker.swift`. Click Create.
    2.  **Import Frameworks:** At the top of `ImagePicker.swift`, add:
        ```swift
        import SwiftUI
        import UIKit
        // Vision will be needed in the next step, import it now
        import Vision
        ```
    3.  **Define ImagePicker Struct:** Create the struct conforming to `UIViewControllerRepresentable`:
        ```swift
        struct ImagePicker: UIViewControllerRepresentable {
            // Bindings to communicate back to ContentView
            @Binding var selectedImage: UIImage?
            @Binding var visionResults: [VNRecognizedTextObservation] // Pass this binding now

            // Environment variable to dismiss the sheet
            @Environment(\.presentationMode) var presentationMode

            // Coordinator handles delegate methods - Defined Next
            func makeCoordinator() -> Coordinator {
                Coordinator(self)
            }

            // Creates the UIImagePickerController - Defined After Coordinator
            func makeUIViewController(context: Context) -> UIImagePickerController {
                 // Implementation below
            }

            // No updates needed from SwiftUI -> UIKit - Defined After makeUIViewController
            func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

            // Coordinator Class (Nested inside ImagePicker struct)
            class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
                let parent: ImagePicker // Reference to the parent ImagePicker struct

                init(_ parent: ImagePicker) {
                    self.parent = parent
                }

                // Delegate: Image was picked
                func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
                    print("Image picked") // Debugging
                    if let uiImage = info[.originalImage] as? UIImage {
                        // 1. Update the image binding in ContentView
                        parent.selectedImage = uiImage
                        // 2. Clear any old Vision results immediately
                        parent.visionResults = []
                        // 3. Call the processing function (to be added in Step 3)
                        parent.processImage(uiImage)
                    } else {
                        print("Could not get original image")
                    }
                    // 4. Dismiss the picker
                    parent.presentationMode.wrappedValue.dismiss()
                }

                // Delegate: Picker was cancelled
                func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
                    print("Image picker cancelled") // Debugging
                    parent.presentationMode.wrappedValue.dismiss()
                }
            } // End of Coordinator Class

            // Function to Start Vision Processing (Added here, implemented in Step 3)
            func processImage(_ image: UIImage) {
                 // Implementation will go here in the next step
                 print("Placeholder: processImage called. Implement Vision request here.")
            }

        } // End of ImagePicker Struct
        ```
    4.  **Implement `makeUIViewController`:** Add this function *inside* the `ImagePicker` struct (replace the comment above):
        ```swift
        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.delegate = context.coordinator // Use the Coordinator for delegates
            // Check if camera is available on the device
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                 picker.sourceType = .camera
            } else {
                 // If no camera (e.g., Simulator), use the photo library
                 print("Camera not available - using photo library")
                 picker.sourceType = .photoLibrary
            }
            return picker
        }
        ```
    5.  **Implement `updateUIViewController`:** Add this function *inside* the `ImagePicker` struct (replace the comment above):
        ```swift
        func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
            // Nothing to update in this simple case
        }
        ```
    6.  **Update ContentView:** Go back to `ContentView.swift`. Find the `.sheet` modifier. Replace the placeholder `Text` view with the actual `ImagePicker`, passing the bindings:
        ```swift
        .sheet(isPresented: $showingImagePicker) {
            // Present the ImagePicker view we just created
            ImagePicker(selectedImage: $capturedImage, visionResults: $visionResults)
        }
        ```
    7.  **Verification:** Build and run the app (Cmd+R). Tap "Scan Document". The camera interface (or photo library on Simulator) should appear. Take a picture and tap "Use Photo" (or select a photo). The picker should dismiss, and you should see "Image picked" and "Placeholder: processImage called..." in the Xcode console. Cancel the picker; it should dismiss, and you should see "Image picker cancelled". The image area in the UI will *not* update yet. Stop the app.

---

### Step 3: Implement Vision Text Recognition Request

* **3.A: Functional Requirements:**
    * FR3.1: Initiate Vision framework analysis after an image is confirmed in the picker.
    * FR3.2: Perform text detection and OCR using `VNRecognizeTextRequest`.
    * FR3.3: Store the results (observations containing text and boxes) upon completion.
* **3.B: Non-Functional Requirements:**
    * NFR3.1: Vision processing must run on a background thread.
    * NFR3.2: Results must be delivered back to the main thread to update state variables safely.
    * NFR3.3: Use `.accurate` recognition level.
    * NFR3.4: Handle potential errors during request creation or performance.
* **3.C: Technical Design & Implementation:**
    1.  **Locate `processImage` Function:** Open `ImagePicker.swift`. Find the `processImage(_ image: UIImage)` function definition you added at the end of the struct in the previous step.
    2.  **Implement `processImage`:** Replace the `print(...)` placeholder inside `processImage` with the following implementation:
        ```swift
        func processImage(_ image: UIImage) {
            // 1. Get the CGImage version of the UIImage
            guard let cgImage = image.cgImage else {
                print("Error: Failed to get CGImage from UIImage.")
                // Optionally: Clear results or show an error state via bindings
                self.visionResults = []
                return
            }

            print("Starting Vision processing on background thread...")

            // 2. Dispatch the Vision request to a background thread
            DispatchQueue.global(qos: .userInitiated).async {
                // 3. Create a Vision Image Request Handler
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])

                // 4. Create the Text Recognition Request
                //    The completion handler will be called when Vision processing is done.
                let textRequest = VNRecognizeTextRequest { (request, error) in
                    // 5. Switch back to the main thread to process results
                    DispatchQueue.main.async {
                        print("Vision processing finished. Processing results on main thread...")
                        // 6. Handle potential errors from the Vision request itself
                        if let error = error {
                            print("Vision Error: \(error.localizedDescription)")
                            self.visionResults = [] // Clear results on error
                            return
                        }

                        // 7. Cast the results to the expected type
                        guard let observations = request.results as? [VNRecognizedTextObservation] else {
                            print("Error: Could not cast Vision results to [VNRecognizedTextObservation].")
                            self.visionResults = []
                            return
                        }

                        // 8. Success! Update the binding variable.
                        //    This will update the @State variable in ContentView.
                        print("Vision success: Found \(observations.count) text observations.")
                        self.visionResults = observations
                    } // End of main thread dispatch
                } // End of VNRecognizeTextRequest completion handler

                // 9. Configure the request for accuracy
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = true // Optional: improves results usually

                // 10. Perform the request
                do {
                    try requestHandler.perform([textRequest])
                } catch {
                    // Handle errors that occur when *starting* the request
                    DispatchQueue.main.async { // Report error on main thread
                         print("Error: Failed to perform Vision request: \(error.localizedDescription)")
                         self.visionResults = [] // Clear results on error
                    }
                }
            } // End of background thread dispatch
        } // End of processImage function
        ```
    3.  **Verification:** Build and run the app (Cmd+R). Tap "Scan Document", take/select a picture containing some clear text. After the picker dismisses, check the Xcode console. You should see messages like:
        * "Image picked"
        * "Starting Vision processing on background thread..."
        * "Vision processing finished. Processing results on main thread..."
        * "Vision success: Found X text observations." (where X > 0 if text was found).
        The UI will *still* not show the image or the text results yet, but the processing is happening. Stop the app.

---

### Step 4: Store and Prepare Vision Results for Display

* **4.A: Functional Requirements:**
    * FR4.1: Ensure the `[VNRecognizedTextObservation]` results from Vision are correctly stored in the state variable used by `ContentView`.
* **4.B: Non-Functional Requirements:**
    * NFR4.1: The storage mechanism must use SwiftUI's state management (`@State` via `@Binding`) to trigger automatic UI updates.
* **4.C: Technical Design & Implementation:**
    1.  **Confirm State Variable:** In `ContentView.swift`, verify the `@State` variable exists:
        ```swift
        @State private var visionResults: [VNRecognizedTextObservation] = []
        ```
    2.  **Confirm Binding:** In `ContentView.swift`, verify the `.sheet` modifier passes this state variable using a binding (`$`) to `ImagePicker`:
        ```swift
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $capturedImage, visionResults: $visionResults) // Ensure $visionResults is here
        }
        ```
    3.  **Confirm Binding Declaration:** In `ImagePicker.swift`, verify the `@Binding` property exists:
        ```swift
        @Binding var visionResults: [VNRecognizedTextObservation]
        ```
    4.  **Confirm State Update:** In `ImagePicker.swift`, inside the `processImage` function's completion handler (within the `DispatchQueue.main.async` block), verify the line that updates the state via the binding:
        ```swift
        self.visionResults = observations // This updates the @State in ContentView
        ```
    5.  **Verification:** No new code is written in this step; it's about confirming the connections made previously. Run the app, scan an image with text, and check the console log for the "Vision success: Found X text observations" message. Add a temporary debug `Text` view inside `ContentView`'s body like `Text("Observations: \(visionResults.count)")` to visually confirm the count updates after scanning. Remove the temporary `Text` view afterwards. Stop the app.

---

### Step 5: Display Extracted Text Results

* **5.A: Functional Requirements:**
    * FR5.1: The UI must display the text strings derived from the stored `visionResults`.
    * FR5.2: Each distinct text observation should result in a separate displayed text item.
* **5.B: Non-Functional Requirements:**
    * NFR5.1: The text display area must update automatically when `visionResults` changes.
    * NFR5.2: Text should be presented clearly, for example, in a list format.
* **5.C: Technical Design & Implementation:**
    1.  **Locate Text Display Area:** In `ContentView.swift`, find the `List` designated for displaying text results (created in Step 1).
    2.  **Implement Conditional Logic & Iteration:** Replace the placeholder `Text` inside the `Section("Extracted Text:") { ... }` block with the following logic:
        ```swift
        Section("Extracted Text:") {
            // Check if an image has been processed but no results found
            if visionResults.isEmpty && capturedImage != nil {
                 Text("Processing complete. No text found.")
                    .foregroundColor(.gray)
            // Check if no image has been scanned yet
            } else if visionResults.isEmpty && capturedImage == nil {
                 Text("Scan an image to view extracted text.")
                    .foregroundColor(.gray)
            // Otherwise, display the results found
            } else {
                 // Iterate over each observation found by Vision
                 ForEach(visionResults, id: \.uuid) { observation in
                     // Get the most confident text recognition result
                     let recognizedText = observation.topCandidates(1).first?.string ?? "Unable to read text"
                     // Display it
                     Text(recognizedText)
                 }
            }
        }
        ```
    3.  **Verification:** Build and run the app (Cmd+R). Tap "Scan Document", take/select a picture containing text. After the picker dismisses and processing completes (may take a second), the "Extracted Text" list should automatically populate with the text found in the image. If no text is found, it should indicate that. Stop the app.

---

### Step 6: Display Bounding Box Overlays

* **6.A: Functional Requirements:**
    * FR6.1: Draw rectangular boxes overlaid on the displayed `capturedImage`.
    * FR6.2: Each box must visually correspond to the location and size of a `VNRecognizedTextObservation`'s `boundingBox`.
* **6.B: Non-Functional Requirements:**
    * NFR6.1: Boxes must only appear when `visionResults` contains observations.
    * NFR6.2: Coordinate calculations must accurately map Vision's normalized, bottom-left origin system to SwiftUI's top-left, point-based system within the displayed image's frame.
    * NFR6.3: Boxes should be styled for visibility (e.g., red outline).
* **6.C: Technical Design & Implementation:**
    1.  **Create Overlay File:** In Xcode, go to File -> New -> File... Select "SwiftUI View" under the User Interface tab. Click Next. Name the file `BoundingBoxOverlay.swift`. Click Create.
    2.  **Define Overlay Struct:** Open `BoundingBoxOverlay.swift`. Replace its contents with:
        ```swift
        import SwiftUI
        import Vision // Need Vision types

        struct BoundingBoxOverlay: View {
            // Input: The observations containing bounding boxes
            let observations: [VNRecognizedTextObservation]
            // Removed imageSize for POC simplicity, rely on GeometryReader

            var body: some View {
                // GeometryReader gives the size of the space available for the overlay
                GeometryReader { geometry in
                    // Loop through each observation to draw its box
                    ForEach(observations, id: \.uuid) { observation in
                        // Get the normalized bounding box (0-1 range) from Vision
                        let visionBoundingBox = observation.boundingBox

                        // Convert Vision's coordinates (origin at bottom-left)
                        // to SwiftUI's coordinates (origin at top-left)
                        // inside the geometry reader's frame size.

                        let viewWidth = geometry.size.width
                        let viewHeight = geometry.size.height

                        // Calculate the top-left corner's Y coordinate
                        // Vision's Y starts from the bottom, SwiftUI's from the top.
                        let yCoordinate = (1.0 - visionBoundingBox.origin.y - visionBoundingBox.height) * viewHeight

                        // Calculate the frame for the SwiftUI rectangle
                        let boundingBoxRect = CGRect(
                            x: visionBoundingBox.origin.x * viewWidth,
                            y: yCoordinate,
                            width: visionBoundingBox.width * viewWidth,
                            height: visionBoundingBox.height * viewHeight
                        )

                        // Draw the rectangle shape using the calculated frame
                        Rectangle()
                            .path(in: boundingBoxRect) // Create path from CGRect
                            .stroke(Color.red, lineWidth: 2) // Style with a red border
                    }
                } // End of GeometryReader
            } // End of body
        } // End of struct
        ```
    3.  **Apply Overlay in ContentView:** Open `ContentView.swift`. Find the `Image(uiImage: image)` line within the `if let image = capturedImage` block. Add the `.overlay(...)` modifier *after* the `.scaledToFit()` modifier:
        ```swift
        if let image = capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                // Add the overlay here, passing the visionResults
                .overlay(BoundingBoxOverlay(observations: visionResults))
        } else { ... }
        ```
    4.  **Verification:** Build and run the app (Cmd+R). Scan an image containing text. After processing, you should now see both the image displayed, the extracted text listed below it, *and* red rectangles drawn directly on top of the image, outlining the areas where the text was detected. Test with images where text is in different locations. Stop the app.
