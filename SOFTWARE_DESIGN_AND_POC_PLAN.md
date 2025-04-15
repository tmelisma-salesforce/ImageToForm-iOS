# Software Design Document & POC Plan: Simple Image-to-Text Scanner with Classification

**Document Version:** 2.0 (Simplified Scope + Classification)
**Date:** April 14, 2025
**Project:** ImageToForm-iOS (Simplified POC with Classification)

**Purpose:** This document outlines the software architecture, detailed design, and a step-by-step implementation plan for a simplified iOS application. The application's goal is to capture an image via the camera, perform on-device **Image Classification** to identify the main subject, perform **Optical Character Recognition (OCR)** to extract text, and display both the classification and raw text results. This document is intended for developers, including junior engineers requiring explicit instructions.

---

## Part 1: Software Architecture Outline (Simplified Vision with Classification)

This section describes the high-level structure for the simplified application focused on capturing an image, classifying its content, and extracting raw text.

**1.1. Goal:**
To create a basic, functional iOS application that demonstrates on-device image capture, **Image Classification**, and Optical Character Recognition (OCR), presenting both the classification label and the raw text results to the user.

**1.2. Key Architectural Principles:**
* **Simplicity:** Focus on the core workflow: Launch -> Capture -> Process (Classify + OCR) -> Display Results.
* **On-Device Processing:** Image classification and text recognition occur locally using system frameworks.
* **Clear Flow:** User navigation between the distinct stages (Welcome, Capture, Processing, Results) is straightforward.
* **Modularity (Basic):** Separate UI views for distinct stages; distinct request types within the extraction service.

**1.3. Major Architectural Components:**

1.  **Presentation Layer (UI):**
    * **Responsibility:** Renders the different screens (Welcome, Camera, Processing Indicator, Results). Handles navigation and basic user interaction. Displays *both* the classification result and the extracted text/boxes.
    * **Sub-components:** `WelcomeView`, `CameraView` (or wrapper), `ProcessingIndicatorView`, `ResultsView`. State management for navigation and data display.
2.  **Application Logic & Coordination Layer:**
    * **Responsibility:** Manages the sequence of presenting views. Handles state transitions between capturing, processing, and displaying results. Passes captured image data to the extraction service. Receives *both* classification and OCR results and passes them to the UI Layer.
    * **Sub-components:** Navigation logic, State variables (`@State`), potentially a simple coordinator/ViewModel.
3.  **Capture Service (Simplified):**
    * **Responsibility:** Interfaces with the system's camera framework (`UIImagePickerController` or basic `AVFoundation`) to present a camera interface and retrieve a captured still image.
    * **Sub-components:** Wrapper for `UIImagePickerController` or basic Camera Session Manager.
4.  **Core Extraction Service (Simplified & Enhanced):**
    * **Responsibility:** Takes a captured image and performs ML inference using Apple's `Vision` framework. It now handles *two* types of requests:
        * **Image Classification:** Identifies the main subject using `VNClassifyImageRequest` and a pre-trained model.
        * **Text Recognition (OCR):** Extracts text using `VNRecognizeTextRequest`.
    * Returns *both* the classification label(s) and the raw text recognition results.
    * **Sub-components:** Vision Request Handler executing `VNClassifyImageRequest` and `VNRecognizeTextRequest`.

**1.4. High-Level Data and Control Flow:**

User initiates from `WelcomeView`. Coordinator presents `CameraView`. User captures `UIImage`. Coordinator receives image, triggers `ProcessingIndicatorView`, and sends image to `Core Extraction Service`. Extraction Service performs *both* Classification and OCR (potentially concurrently). Service returns results (e.g., `[VNClassificationObservation]` and `[VNRecognizedTextObservation]`). Coordinator passes these results to the `ResultsView` for display.

**1.5. Potential Future Extensions (Out of Scope for this Design):**
Image preprocessing, intelligent text parsing, data validation, form integration, real-time analysis, context awareness based on classification, etc.

---

## Part 2: Detailed Design Document (Simplified Vision with Classification)

This section provides more specific design details for the components of the simplified image classification and text scanning application.

**2.1. Presentation Layer:**
* **UI Framework:** SwiftUI.
* **Views:**
    * `WelcomeView`: Unchanged from previous simplified design (Title, Button).
    * `CameraView`: Unchanged (`UIImagePickerController` wrapper).
    * `ProcessingIndicatorView`: Unchanged (Simple overlay with `ProgressView`).
    * `ResultsView`: **Modified.** Now needs to display:
        * The captured image (optional).
        * Bounding box overlays (optional).
        * The top **Image Classification Result** (e.g., `Text("Detected: \(classificationLabel)")`).
        * The `List` of raw extracted **OCR Text Strings**.
    Takes `UIImage`, `[VNRecognizedTextObservation]`, and the top `String` classification label as input (via `@State` variables in `ContentView`).
* **State Management:** Requires an additional `@State` variable in `ContentView` to hold the top classification result string (e.g., `@State private var classificationLabel: String = ""`).

**2.2. Application Logic & Coordination Layer:**
* **Responsibilities:** Handles navigation/presentation state. Receives `UIImage`. Triggers `Core Extraction Service`. Updates `isProcessing` state. Receives *both* classification and OCR results. Updates state variables for `classificationLabel` and `visionResults`. Transitions UI to show `ResultsView`.
* **Implementation:** Managed within `ContentView` using `@State`, `.onChange`, and helper functions.

**2.3. Capture Service (Simplified):**
* **Technology:** `UIImagePickerController` wrapped using `UIViewControllerRepresentable`.
* **Implementation:** No changes needed from the previous step (Step 2 implementation).

**2.4. Core Extraction Service (Simplified & Enhanced):**
* **Technology:** Apple `Vision` framework.
* **Implementation:** Modify the function `performVisionRequest` (likely within `ContentView` for POC).
    1.  **Input:** `UIImage`.
    2.  **Get `CGImage` & Orientation:** Determine correct `CGImagePropertyOrientation`.
    3.  **Background Dispatch:** Use `DispatchQueue.global().async`.
    4.  **Create Handler:** `VNImageRequestHandler(cgImage:orientation:options:)`.
    5.  **Create Requests:**
        * **`VNRecognizeTextRequest`:** As before, with completion handler to process `[VNRecognizedTextObservation]`.
        * **`VNClassifyImageRequest`:** Create this request.
            * **Model:** Decide whether to use the Vision default classifier or specify a bundled `.mlmodel`. For a bundled model (e.g., `MobileNetV2.mlmodel` added to the project), load it first: `guard let model = try? VNCoreMLModel(for: MobileNetV2().model) else { // handle error }`, then initialize the request: `VNClassifyImageRequest(model: model, completionHandler: { ... })`. If using the default, initialize without a model: `VNClassifyImageRequest(completionHandler: { ... })`.
            * **Completion Handler:** The handler receives `request` and `error`. Process `request.results` cast to `[VNClassificationObservation]`. Extract the identifier and confidence of the top result (`results.first?.identifier`, `results.first?.confidence`).
    6.  **Perform Requests:** Perform *both* requests using the *same* handler: `try requestHandler.perform([textRequest, classificationRequest])`.
    7.  **Result Handling:** The completion handlers for *both* requests need to dispatch back to the main thread and update their respective `@State` variables (`visionResults` and `classificationLabel`). Ensure `isProcessing` is set to `false` *after both* potential asynchronous completions might have occurred (or more simply, after `requestHandler.perform` completes in the background task's scope, before dispatching results back). A `DispatchGroup` could be used for more precise synchronization if needed, but might overcomplicate the POC. Let's update state in each handler and set `isProcessing` false after the perform call returns in the background task (before dispatching results). *Correction*: Set `isProcessing` false on the main thread *after* results are processed, potentially using a counter or DispatchGroup if handling completions separately, or just once if results are processed sequentially. Let's keep it simple: set `isProcessing = false` within *each* completion handler right before updating the state variable, ensuring it happens on the main thread.

**2.5. Data Flow:**
`Button Tap` -> `Present CameraView` -> `User Captures Image` -> `Delegate returns UIImage` -> `Trigger Processing Indicator UI` & `Call Core Extraction Service (background)` -> `Extraction Service performs Classification AND OCR` -> `Vision returns [VNClassificationObservation]` AND `[VNRecognizedTextObservation]` -> `Update classificationLabel AND visionResults State (main thread)` -> `Hide Processing Indicator UI` -> `Display ResultsView UI`.

**2.6. Threading Model:** Remains the same: UI on Main, Vision on Background, Results/State updates back on Main.

---

## Part 3: Proof of Concept (POC) - Implementation Plan (with Classification)

This section provides a step-by-step guide for building the POC application *including* image classification.

**Goal:** Create an app: Welcome -> Camera -> Processing (Classify+OCR) -> Results (Classification Label + Raw Text List + Boxes).

**Technology:** Swift, SwiftUI, Vision, UIImagePickerController, Core ML (for classification model).

---

### Step 1: Project Setup & Welcome Screen

* **1.A: Functional Requirements:**
    * FR1.1: App launches to "Welcome" screen with title/message.
    * FR1.2: "Start Scan" button triggers camera presentation.
* **1.B: Non-Functional Requirements:**
    * NFR1.1: iOS Project using Swift, SwiftUI.
    * NFR1.2: `Info.plist` includes `NSCameraUsageDescription`.
    * NFR1.3: State variables declared for navigation/results (including new one for classification).
    * NFR1.4: **(New)** Add a pre-trained Core ML Image Classification model file (e.g., `MobileNetV2.mlmodel`) to the project. (See Note Below)
* **1.C: Technical Design & Implementation:**
    1.  **Project Setup:** Ensure initial project setup (Step 0 from previous plan) is complete, including `Info.plist` key.
    2.  **Add Classification Model:**
        * Download a pre-trained image classification model in `.mlmodel` format. A common choice is `MobileNetV2`. You can often find these on Apple's Machine Learning website or convert them using `coremltools`.
        * Drag the downloaded `MobileNetV2.mlmodel` file into your Xcode project navigator. Ensure it's added to your app's target membership. Xcode will automatically generate a Swift class for it (e.g., `MobileNetV2`).
        * *(Alternative: Skip adding a model file and rely on Vision's default classifier by initializing `VNClassifyImageRequest` without a model. Results will be less predictable).*
    3.  **ContentView State:** Open `ContentView.swift`. Add the *new* state variable alongside the existing ones:
        ```swift
        // Inside struct ContentView: View { ... }
        @State private var showCamera = false
        @State private var capturedImage: UIImage? = nil
        @State private var visionResults: [VNRecognizedTextObservation] = []
        @State private var isProcessing = false
        @State private var classificationLabel: String = "" // New state for classification result
        ```
    4.  **Welcome UI:** Implement the `WelcomeView` struct (or keep inline in `ContentView`) as per the previous Step 1. Ensure the "Start Scan" button clears `classificationLabel` as well:
        ```swift
        // Inside WelcomeView's Button action or ContentView's Button action
        self.capturedImage = nil
        self.visionResults = []
        self.classificationLabel = "" // Clear classification too
        self.showCamera = true
        ```
    5.  **Verification:** Build and run. App should show the Welcome screen. Tapping "Start Scan" should still present the placeholder/camera sheet trigger. Ensure the project builds with the added `.mlmodel` file.

*(Note on ML Model: Finding and adding the `.mlmodel` is a prerequisite setup step here. If unavailable, modify the technical design in Step 3 to use the default `VNClassifyImageRequest()` initializer without a model argument.)*

---

### Step 2: Camera Screen & Image Capture

* **2.A: Functional Requirements:** (Unchanged from previous plan)
    * FR2.1: Present camera/library upon trigger.
    * FR2.2: Allow capture/selection or cancellation.
    * FR2.3: Receive `UIImage` on confirmation.
    * FR2.4: Dismiss picker automatically.
* **2.B: Non-Functional Requirements:** (Unchanged from previous plan)
    * NFR2.1: Use `UIImagePickerController` wrapper.
    * NFR2.2: Handle delegates correctly.
    * NFR2.3: Pass `UIImage` via `@Binding`.
    * NFR2.4: Use `presentationMode` for dismissal.
* **2.C: Technical Design & Implementation:**
    1.  **Implement `ImagePicker.swift`:** Ensure the `ImagePicker.swift` file exists and contains the code from the previous plan's Step 2 implementation (the `UIViewControllerRepresentable` wrapper). **No changes are needed** in `ImagePicker.swift` itself for adding classification, as it only deals with capturing the image.
    2.  **Connect in `ContentView`:** Ensure `ContentView.swift` still presents the `ImagePicker` in its `.fullScreenCover` modifier, passing the `$capturedImage` binding.
    3.  **Verification:** Build and run. Verify that tapping "Start Scan" presents the camera/library, and selecting/cancelling works, updating the `capturedImage` state in `ContentView` (which will trigger the `.onChange` modifier added in the next step).

---

### Step 3: Processing Indicator & Vision Tasks (OCR + Classification)

* **3.A: Functional Requirements:**
    * FR3.1: Show processing indicator after image capture.
    * FR3.2: Initiate Vision OCR task *and* Vision Image Classification task.
    * FR3.3: Store OCR results (`[VNRecognizedTextObservation]`).
    * FR3.4: Store the top Classification result (`String` label).
    * FR3.5: Hide processing indicator upon completion of *both* tasks (or on error).
* **3.B: Non-Functional Requirements:**
    * NFR3.1: Indicator overlays UI.
    * NFR3.2: Vision tasks run on background thread.
    * NFR3.3: State updates on main thread.
    * NFR3.4: Use `VNRecognizeTextRequest` and `VNClassifyImageRequest`.
    * NFR3.5: Use the bundled pre-trained classification model (e.g., `MobileNetV2.mlmodel`) or Vision default.
* **3.C: Technical Design & Implementation:**
    1.  **Add State & Trigger:** Ensure `ContentView.swift` has `@State private var isProcessing = false` and the `.onChange(of: capturedImage)` modifier that sets `isProcessing = true` and calls `performVisionRequest(on: image)`.
    2.  **Add Processing Indicator Overlay:** Ensure `ContentView` has the `.overlay` modifier that shows `ProcessingIndicatorView` when `isProcessing` is true. (Code for `ProcessingIndicatorView` struct remains the same).
    3.  **Modify `performVisionRequest`:** Update the function *inside* `ContentView.swift` to handle both requests:
        ```swift
        // Replace the existing performVisionRequest function in ContentView
        private func performVisionRequest(on image: UIImage) {
            guard let cgImage = image.cgImage else {
                print("Error: Failed to get CGImage")
                DispatchQueue.main.async { isProcessing = false }
                return
            }

            let imageOrientation = cgOrientation(from: image.imageOrientation) // Use helper from previous fix
            print("DEBUG: UIImage Orientation raw value: \(image.imageOrientation.rawValue), CGImagePropertyOrientation: \(imageOrientation.rawValue)")

            print("Starting Vision processing (OCR + Classification) on background thread...")
            isProcessing = true // Ensure indicator is shown

            // Prepare requests outside the background dispatch if models need loading
            // --- Classification Request Setup ---
            let classificationRequest: VNRequest
            do {
                 // Option 1: Use a bundled MobileNetV2 model
                 // Make sure MobileNetV2.mlmodel is added to your project & target
                 let model = try VNCoreMLModel(for: MobileNetV2().model) // Assumes MobileNetV2 class generated by Xcode
                 let request = VNClassifyImageRequest(model: model) { (request, error) in
                      // Process results on main thread
                      DispatchQueue.main.async {
                           if let error = error {
                                print("Classification Error: \(error.localizedDescription)")
                                self.classificationLabel = "Error classifying"
                           } else if let results = request.results as? [VNClassificationObservation], let topResult = results.first {
                                print("Classification success: Top result = \(topResult.identifier) (\(topResult.confidence))")
                                self.classificationLabel = "\(topResult.identifier) (\(String(format: "%.0f%%", topResult.confidence * 100)))"
                           } else {
                                print("Classification failed: No results or cast failed.")
                                self.classificationLabel = "Classification failed"
                           }
                           // Note: We don't set isProcessing=false here yet, wait for both requests potentially
                      }
                 }
                 classificationRequest = request

                 // Option 2: Use Vision's default classifier (comment out Option 1 if using this)
                 /*
                 let request = VNClassifyImageRequest { (request, error) in
                     // Similar completion handler logic as above...
                 }
                 classificationRequest = request
                 */

            } catch {
                 print("Failed to load classification model: \(error)")
                 // Handle model loading error - maybe skip classification
                 classificationRequest = VNClassifyImageRequest() // Create dummy/empty request or handle differently
                 DispatchQueue.main.async {
                      self.classificationLabel = "Model load error"
                 }
            }
            // --- End Classification Request Setup ---


            // --- Text Recognition Request Setup ---
            let textRequest = VNRecognizeTextRequest { (request, error) in
                 // Process results on main thread
                 DispatchQueue.main.async {
                      if let error = error {
                           print("OCR Error: \(error.localizedDescription)")
                           self.visionResults = []
                      } else if let observations = request.results as? [VNRecognizedTextObservation] {
                           print("OCR success: Found \(observations.count) observations.")
                           self.visionResults = observations
                      } else {
                           print("OCR failed: Could not cast results.")
                           self.visionResults = []
                      }
                      // Note: We don't set isProcessing=false here yet
                 }
            }
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            // --- End Text Recognition Request Setup ---


            // --- Perform Both Requests ---
            DispatchQueue.global(qos: .userInitiated).async {
                 let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation, options: [:])
                 do {
                      print("Performing Text + Classification requests...")
                      try requestHandler.perform([textRequest, classificationRequest]) // Perform both
                      print("Request handler finished.")
                 } catch {
                      print("Error: Failed to perform Vision requests: \(error.localizedDescription)")
                      // Ensure UI state is reset on failure
                      DispatchQueue.main.async {
                           self.visionResults = []
                           self.classificationLabel = "Processing error"
                      }
                 }
                 // Set processing to false on main thread *after* perform returns
                 DispatchQueue.main.async {
                    print("Setting isProcessing = false")
                    isProcessing = false
                 }
            } // End background dispatch
        } // End performVisionRequest

        // Ensure cgOrientation helper function is present in ContentView
        private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
             switch uiOrientation {
             // ... (include the full switch statement from the previous step's fix) ...
             case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
             case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
             @unknown default: return .up
             }
        }
        ```
    4.  **Verification:** Build and run. Scan an image (e.g., the envelope `IMG_1144.jpg` or the code `IMG_1143.jpg`). Observe the processing indicator. Check the console logs. You should now see logs for *both* Classification success/failure *and* OCR success/failure. `isProcessing` should become false after both have likely completed (or failed). The UI won't show the classification yet.

---

### Step 4: Update Results Display Screen

* **4.A: Functional Requirements:**
    * FR4.1: Display the top image classification label prominently.
    * FR4.2: Continue to display the captured image (optional).
    * FR4.3: Continue to display bounding boxes (optional).
    * FR4.4: Continue to display the list of raw extracted text strings.
    * FR4.5: Retain the "Scan New" functionality.
* **4.B: Non-Functional Requirements:**
    * NFR4.1: Results screen appears after processing.
    * NFR4.2: Use SwiftUI.
    * NFR4.3: Display handles empty/error states for classification label.
* **4.C: Technical Design & Implementation:**
    1.  **Modify `ResultsView`:** Open `ContentView.swift` and find the `ResultsView` struct definition (or the inline equivalent if you didn't extract it).
    2.  **Add Classification Binding:** Add the binding for the classification label:
        ```swift
        // Inside struct ResultsView: View { ... }
        @Binding var classificationLabel: String // Add this binding
        ```
    3.  **Pass Binding from `ContentView`:** In `ContentView`'s body, update the creation of `ResultsView` to pass the new binding:
        ```swift
        // Inside ContentView -> body -> if capturedImage != nil { ... }
        ResultsView(
            capturedImage: $capturedImage,
            visionResults: $visionResults,
            isProcessing: $isProcessing,
            showCamera: $showCamera,
            classificationLabel: $classificationLabel // Pass the new binding
        )
        ```
    4.  **Display Classification Label:** In `ResultsView`'s `body`, add a `Text` view to display the classification result, perhaps above the image or list:
        ```swift
        // Inside ResultsView -> body -> VStack { ... }
        // Add this Text view, e.g., before the ZStack for the image
        Text("Detected: \(classificationLabel.isEmpty ? "N/A" : classificationLabel)")
             .font(.title2)
             .padding(.top)

        // ... rest of ResultsView body (ZStack with Image/Overlay, List) ...
        ```
    5.  **Verification:** Build and run. Scan an image (e.g., the envelope). After processing, the Results screen should appear. Verify:
        * The title is "Scan Results".
        * The new "Detected: [Label] (Confidence%)" text appears (e.g., "Detected: envelope (95%)" or similar, depending on the model used). If classification failed, it should show "Detected: N/A" or an error message.
        * The image, bounding boxes, and text list still appear correctly below the classification label.
        * The "Scan New" button works to reset the process.
