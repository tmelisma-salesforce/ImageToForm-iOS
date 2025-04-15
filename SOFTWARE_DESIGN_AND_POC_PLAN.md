# Software Design Document & POC Implementation Plan: ImageToForm-iOS

**Document Version:** 1.0
**Date:** April 14, 2025
**Project:** ImageToForm-iOS Proof of Concept

**Purpose:** This document outlines the software architecture and detailed design for the ImageToForm-iOS application's full vision. It also provides a step-by-step requirements breakdown and technical implementation guide for building the initial Proof of Concept (POC), intended for developers, including junior engineers.

---

## Part 1: Software Architecture Outline (Full Vision)

This section describes the high-level structure and components envisioned for the complete, robust application designed for on-device form filling from images.

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

The typical flow involves the UI Layer initiating a scan request via the Coordination Layer. The Coordinator activates the Capture Service, which provides a processed image buffer. This buffer is passed to the Core Extraction Service for OCR. The resulting raw text, along with context, goes to the Parsing & Validation Service. The structured, validated data (or errors) are returned via the Coordinator to the Presentation Layer, which updates the form fields or displays appropriate messages, always allowing user review. Asynchronous operations with completion handlers, delegates, or reactive patterns (like Combine) manage the flow between background processing and main thread UI updates.

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
* **Vision Framework:** Primary interface. Encapsulate `VNImageRequestHandler` creation and `VNRequest` execution.
* **Text Recognition:** Utilize `VNRecognizeTextRequest`. Configure properties like `recognitionLevel` (`.accurate` preferred for stills), `usesLanguageCorrection`, potentially `customWords` if common non-dictionary terms are expected (like specific medical terms).
* **Object Detection (Optional):** If specific object detection (beyond simple rectangles) is needed, use `VNCoreMLRequest` with a `.mlmodel` file. The model itself needs to be sourced (pre-trained if available and suitable, or custom-trained). Model management involves bundling or using Core ML's deployment features.
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

## Part 3: Proof of Concept (POC) - Implementation Plan

This section provides a step-by-step guide for building the minimal POC. Each step includes Functional Requirements (FR), Non-Functional Requirements (NFR), and Technical Design/Implementation details.

**Goal:** Validate core on-device text detection and OCR using Vision on a single captured image, displaying raw results with visual feedback.

**Technology:** Swift, SwiftUI, Vision, UIImagePickerController.

---

### Step 1: Project Setup & Basic UI Layout

* **1.A: Functional Requirements:**
    * FR1.1: The app must display a screen with a title (e.g., "POC Scanner").
    * FR1.2: The screen must contain a button labeled "Scan Document".
    * FR1.3: The screen must have a designated area to display a captured image (initially empty or showing a placeholder message).
    * FR1.4: The screen must have a designated area to display extracted text results (initially empty or showing a placeholder message).
* **1.B: Non-Functional Requirements:**
    * NFR1.1: The project must be configured for iOS using Swift and SwiftUI.
    * NFR1.2: Basic privacy requirements (Camera Usage description) must be configured in `Info.plist`.
    * NFR1.3: The initial UI layout should be clean and understandable.
    * NFR1.4: Appropriate state variables must be declared to hold future data (captured image, results).
* **1.C: Technical Design & Implementation:**
    1.  **Project Creation:** Follow standard Xcode procedures to create a new iOS App project named `ImageToFormPOC` using the SwiftUI interface and Swift language. Set the minimum deployment target (e.g., iOS 15.0).
    2.  **Info.plist:** Add the key `NSCameraUsageDescription` (Privacy - Camera Usage Description) and provide a user-facing string explaining why camera access is needed.
    3.  **Git Setup:** Initialize a git repository, add the standard Swift `.gitignore` file.
    4.  **ContentView Structure:** Open `ContentView.swift`. Embed the main content within a `NavigationView` (optional, for title). Use a `VStack` for the main vertical layout.
    5.  **State Variables:** Declare the necessary `@State` variables at the top of `ContentView`:
        ```swift
        @State private var capturedImage: UIImage? = nil
        @State private var visionResults: [VNRecognizedTextObservation] = [] // Store full results
        @State private var showingImagePicker = false // To trigger the sheet
        ```
    6.  **UI Elements:**
        * Add `Text` views for titles/placeholders.
        * Add the `Button("Scan Document")` and set its action to toggle the `showingImagePicker` state variable: `self.showingImagePicker = true`.
        * Create a `ZStack` or `VStack` to contain the image display area. Use an `if let image = capturedImage` block. Inside, use `Image(uiImage: image).resizable().scaledToFit()`. Outside (or in an `else` block), display a placeholder `Text`. Add modifiers like `.frame()` and `.border()` to define this area visually.
        * Create a `List` or scrollable `VStack` to display results. Initially, it can just show placeholder text. Later, it will iterate over `visionResults`. Use `Spacer()` to push the button towards the bottom if desired.
    7.  **Sheet Presentation:** Attach the `.sheet(isPresented: $showingImagePicker)` modifier to the main `VStack` or `NavigationView`. The content of the sheet will be the `ImagePicker` view created in the next step.

---

### Step 2: Implement Image Capture Functionality

* **2.A: Functional Requirements:**
    * FR2.1: Tapping the "Scan Document" button must present the native iOS camera interface modally.
    * FR2.2: The user must be able to take a photo using the interface.
    * FR2.3: The user must be able to confirm the taken photo or retake/cancel.
    * FR2.4: If the user confirms a photo, the app must receive the `UIImage` object.
    * FR2.5: If the user cancels, the camera interface must be dismissed without providing an image.
    * FR2.6: The camera interface must be dismissed automatically after the user confirms or cancels.
* **2.B: Non-Functional Requirements:**
    * NFR2.1: The implementation must use the standard `UIImagePickerController` for simplicity in the POC.
    * NFR2.2: The app must correctly handle the delegate callbacks for both successful image picking and cancellation.
    * NFR2.3: The app should attempt to use the camera source type but fall back to the photo library if the camera is unavailable (e.g., running on Simulator).
    * NFR2.4: Captured image data must be passed back to the `ContentView` for display and processing.
* **2.C: Technical Design & Implementation:**
    1.  **Create ImagePicker File:** Create a new Swift file named `ImagePicker.swift`. Import `SwiftUI`, `UIKit`.
    2.  **UIViewControllerRepresentable:** Define a struct `ImagePicker: UIViewControllerRepresentable`.
    3.  **Bindings & Environment:** Add `@Binding` properties for the `selectedImage: UIImage?` and `visionResults: [VNRecognizedTextObservation]` (to pass results back and clear old ones). Add `@Environment(\.presentationMode)` to dismiss the sheet.
    4.  **Coordinator Class:** Define a nested `class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate`. Give it a reference back to its `ImagePicker` parent (`let parent: ImagePicker`).
    5.  **Coordinator Delegates:** Implement the required delegate methods within the `Coordinator`:
        * `imagePickerController(_:didFinishPickingMediaWithInfo:)`: Retrieve the `.originalImage` as a `UIImage`. Assign it to `parent.selectedImage`. Clear the `parent.visionResults` binding (to remove stale results). *Crucially, trigger the image processing function here (to be implemented in Step 3)*. Call `parent.presentationMode.wrappedValue.dismiss()`.
        * `imagePickerControllerDidCancel(_:)`: Simply call `parent.presentationMode.wrappedValue.dismiss()`.
    6.  **Representable Methods:** Implement the required methods in `ImagePicker`:
        * `makeCoordinator() -> Coordinator`: Return `Coordinator(self)`.
        * `makeUIViewController(context: Context) -> UIImagePickerController`: Create an instance of `UIImagePickerController`. Set its `delegate` to `context.coordinator`. Check `UIImagePickerController.isSourceTypeAvailable(.camera)` and set `sourceType` accordingly (use `.camera` if available, otherwise `.photoLibrary`). Return the picker instance.
        * `updateUIViewController(_:context:)`: Leave this empty for the POC.
    7.  **Connect in ContentView:** Ensure the `.sheet` modifier in `ContentView` presents this `ImagePicker` struct, passing the relevant `@State` variables as bindings:
        ```swift
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(selectedImage: $capturedImage, visionResults: $visionResults)
        }
        ```

---

### Step 3: Implement Vision Text Recognition Request

* **3.A: Functional Requirements:**
    * FR3.1: After an image is captured and received (from Step 2), the app must initiate processing.
    * FR3.2: The app must use the Apple Vision framework to analyze the image for text.
    * FR3.3: The analysis must identify regions (bounding boxes) containing text.
    * FR3.4: The analysis must perform OCR to convert the text in those regions into strings.
* **3.B: Non-Functional Requirements:**
    * NFR3.1: Vision processing must execute on a background thread to prevent blocking the UI.
    * NFR3.2: The implementation must use `VNRecognizeTextRequest` with the `.accurate` recognition level.
    * NFR3.3: Basic error handling for the Vision request (e.g., failure to perform, invalid image) must be included.
    * NFR3.4: Results from the Vision request must be passed back to the main thread for state updates.
* **3.C: Technical Design & Implementation:**
    1.  **Create Processing Function:** Define a function responsible for starting the Vision task. A good place for this in the POC structure is within the `ImagePicker` struct (or its Coordinator, though keeping it in the struct might be slightly simpler to call). Let's call it `processImage(_ image: UIImage)`.
    2.  **Call Processing Function:** Ensure this `processImage` function is called from the `imagePickerController(_:didFinishPickingMediaWithInfo:)` delegate method *after* setting the `selectedImage` and clearing `visionResults`.
    3.  **Get CGImage:** Inside `processImage`, safely get the `CGImage` property from the input `UIImage`. If it fails, print an error and return.
    4.  **Dispatch to Background:** Wrap the Vision request setup and execution in `DispatchQueue.global(qos: .userInitiated).async { ... }`.
    5.  **Create Request Handler:** Inside the background dispatch block, create a `VNImageRequestHandler(cgImage: cgImage, options: [:])`.
    6.  **Create Text Request:** Create a `VNRecognizeTextRequest`. Its initializer takes a completion handler `(VNRequest, Error?) -> Void`.
    7.  **Implement Completion Handler:** Define the code inside the completion handler closure:
        * **Switch to Main Thread:** Immediately dispatch the result handling back to the main thread: `DispatchQueue.main.async { ... }`.
        * **Error Check:** Inside the main thread block, check if the `error` parameter is non-nil. If so, print the error and potentially clear the results state variable (`parent.visionResults = []`).
        * **Process Results:** If no error, safely cast `request.results` to `[VNRecognizedTextObservation]`. Use `guard let observations = ... else { return }`.
        * **Update State:** Assign these `observations` to the `@Binding` variable (`parent.visionResults = observations`). This will trigger the UI update in `ContentView`.
    8.  **Configure Request:** Before performing it, set `textRequest.recognitionLevel = .accurate`. Optionally set `textRequest.usesLanguageCorrection = true`.
    9.  **Perform Request:** Inside the background dispatch block (after creating the request), call `try? requestHandler.perform([textRequest])`. Use `try?` or a `do-catch` block to handle potential errors during the *perform* call itself (and print/handle errors appropriately, dispatching back to main thread if needed).

---

### Step 4: Store and Prepare Vision Results for Display

* **4.A: Functional Requirements:**
    * FR4.1: The app must store the results obtained from the Vision framework (`VNRecognizeTextRequest`).
    * FR4.2: The stored results must include both the recognized text strings and their corresponding bounding box information.
* **4.B: Non-Functional Requirements:**
    * NFR4.1: The results must be stored in `@State` variables in `ContentView` so that UI updates automatically when the data changes.
    * NFR4.2: The data structure used should be the `VNRecognizedTextObservation` itself, as it conveniently contains both bounding box and text candidates.
* **4.C: Technical Design & Implementation:**
    1.  **State Variable:** Confirm that the `@State private var visionResults: [VNRecognizedTextObservation] = []` variable exists in `ContentView`.
    2.  **Binding:** Confirm that this state variable is passed as a `@Binding` to the `ImagePicker` struct.
    3.  **Update in Completion Handler:** In Step 3.C.7 (the Vision request completion handler, running on the main thread), the line `self.visionResults = observations` (or `parent.visionResults = observations` if implemented inside `ImagePicker`) correctly assigns the full results array to the state variable. No further processing is needed in *this* step; the raw observations are stored.

---

### Step 5: Display Extracted Text Results

* **5.A: Functional Requirements:**
    * FR5.1: The app must display the text strings extracted during the OCR process (Step 3).
    * FR5.2: Each recognized text block/line should appear as a distinct item in the UI.
    * FR5.3: Placeholder text should indicate states like "Processing...", "No text found", or "Scan an image".
* **5.B: Non-Functional Requirements:**
    * NFR5.1: The display must update automatically when the `visionResults` state variable changes.
    * NFR5.2: The text should be presented in a readable format (e.g., a list).
* **5.C: Technical Design & Implementation:**
    1.  **Locate UI Area:** Go to the `List` or `VStack` designated for text results in `ContentView.swift`.
    2.  **Conditional Content:** Use `if/else if/else` logic based on `capturedImage` and `visionResults` state:
        * If `capturedImage != nil` and `visionResults.isEmpty`: Show "Processing or no text found...".
        * If `capturedImage == nil`: Show "No image scanned yet." or similar.
        * Else (`capturedImage != nil` and `visionResults` is not empty): Proceed to iterate.
    3.  **Iterate Results:** Use `ForEach(visionResults, id: \.uuid) { observation in ... }` to loop through the stored observations. The `\.uuid` makes each observation uniquely identifiable for the loop.
    4.  **Extract & Display Text:** Inside the `ForEach` loop, access the best text candidate: `observation.topCandidates(1).first?.string`. Use the nil-coalescing operator `??` to provide a fallback string like `"Error reading text"` in case `topCandidates` is empty. Display this string using a standard `Text` view.
    5.  **Structure (Optional):** If using a `List`, `ForEach` works directly. If using a `VStack`, ensure it's potentially wrapped in a `ScrollView` if many text results are expected.

---

### Step 6: Display Bounding Box Overlays

* **6.A: Functional Requirements:**
    * FR6.1: The app must draw rectangles (bounding boxes) over the displayed captured image.
    * FR6.2: Each rectangle must correspond visually to the location and size of a text region detected by the Vision framework.
* **6.B: Non-Functional Requirements:**
    * NFR6.1: The bounding boxes must be displayed only when an image has been captured and processed.
    * NFR6.2: The coordinate calculation for the boxes must correctly translate Vision's normalized, bottom-left origin coordinates to the SwiftUI view's top-left origin, point-based coordinate system.
    * NFR6.3: The boxes should be visually distinct (e.g., red stroke).
* **6.C: Technical Design & Implementation:**
    1.  **Create Overlay View:** Create a new SwiftUI `View` struct named `BoundingBoxOverlay`.
    2.  **Input Properties:** Give it `let observations: [VNRecognizedTextObservation]` and `let imageSize: CGSize` properties. `imageSize` is needed if the `Image` view uses `.scaledToFill` and you need the original aspect ratio for scaling calculations, but for `.scaledToFit` used here, the `GeometryReader` size is often sufficient for calculations *within that fitted view*. Let's simplify and primarily use `GeometryReader`'s size for now. (Add `imageSize` property if aspect ratio correction becomes necessary later).
        ```swift
        struct BoundingBoxOverlay: View {
            let observations: [VNRecognizedTextObservation]
            // let imageSize: CGSize // Keep if needed later

            var body: some View { ... }
        }
        ```
    3.  **Use GeometryReader:** Wrap the content of the `BoundingBoxOverlay`'s `body` in a `GeometryReader { geometry in ... }`. This provides the `geometry.size` (the actual size available for drawing the overlay).
    4.  **Iterate Observations:** Inside the `GeometryReader`, use `ForEach(observations, id: \.uuid) { observation in ... }`.
    5.  **Get Normalized Box:** Inside the loop, get `let boundingBox = observation.boundingBox`. This is a `CGRect` with values between 0.0 and 1.0, and its origin `y` is from the bottom edge.
    6.  **Coordinate Conversion:** Calculate the rectangle's frame in the `GeometryReader`'s coordinate space (top-left origin):
        ```swift
        let viewWidth = geometry.size.width
        let viewHeight = geometry.size.height

        // Vision's Y is from bottom, SwiftUI's Y is from top
        let yPosition = (1.0 - boundingBox.origin.y - boundingBox.height) * viewHeight

        let rect = CGRect(
            x: boundingBox.origin.x * viewWidth,
            y: yPosition,
            width: boundingBox.width * viewWidth,
            height: boundingBox.height * viewHeight
        )
        ```
    7.  **Draw Rectangle:** Use the calculated `rect` to draw the box:
        ```swift
        Rectangle()
            .path(in: rect) // Use path(in:) for CGRect drawing
            .stroke(Color.red, lineWidth: 2) // Style the box
        ```
    8.  **Apply Overlay in ContentView:** Go back to `ContentView.swift`. Find the `Image(uiImage: image)` view. Add the `.overlay(...)` modifier:
        ```swift
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay(BoundingBoxOverlay(observations: visionResults)) // Pass the results
        ```
        *(Note: Removed imageSize passing for simplicity, relying on GeometryReader within the overlay)*.
