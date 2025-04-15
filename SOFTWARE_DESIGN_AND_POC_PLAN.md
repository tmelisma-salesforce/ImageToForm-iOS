# Software Design Document & POC Plan: Simple Image-to-Text Scanner

**Document Version:** 1.0 (Simplified Scope)
**Date:** April 14, 2025
**Project:** ImageToForm-iOS (Simplified POC)

**Purpose:** This document outlines the software architecture, detailed design, and a step-by-step implementation plan for a simplified iOS application. The application's goal is to capture an image via the camera, perform on-device text recognition (OCR), and display the raw extracted text strings. This document is intended for developers, including junior engineers requiring explicit instructions.

---

## Part 1: Software Architecture Outline (Simplified Vision)

This section describes the high-level structure for the simplified application focused solely on capturing an image and extracting raw text.

**1.1. Goal:**
To create a basic, functional iOS application that demonstrates on-device image capture and Optical Character Recognition (OCR), presenting the raw text results to the user. This serves as a foundational module for potential future enhancements.

**1.2. Key Architectural Principles:**
* **Simplicity:** Focus on the core workflow: Launch -> Capture -> Process -> Display Results.
* **On-Device Processing:** Text recognition occurs locally using system frameworks.
* **Clear Flow:** User navigation between the distinct stages (Welcome, Capture, Processing, Results) is straightforward.
* **Modularity (Basic):** Separate UI views for distinct stages of the process.

**1.3. Major Architectural Components:**

1.  **Presentation Layer (UI):**
    * **Responsibility:** Renders the different screens of the application (Welcome, Camera, Processing Indicator, Results). Handles basic user navigation and interaction (button taps, image capture confirmation).
    * **Sub-components:** `WelcomeView`, `CameraView` (or wrapper for system camera), `ProcessingIndicatorView`, `ResultsView`. State management for navigation and data display.
2.  **Application Logic & Coordination Layer:**
    * **Responsibility:** Manages the sequence of presenting views. Handles the state transitions between capturing, processing, and displaying results. Passes data (captured image, OCR results) between the UI and the extraction service.
    * **Sub-components:** Navigation logic, State variables (`@State`), potentially a simple coordinator or ViewModel if complexity increases slightly.
3.  **Capture Service (Simplified):**
    * **Responsibility:** Interfaces with the system's camera framework (`UIImagePickerController` or basic `AVFoundation`) to present a camera interface and retrieve a captured still image.
    * **Sub-components:** Wrapper for `UIImagePickerController` or basic Camera Session Manager.
4.  **Core Extraction Service (Simplified):**
    * **Responsibility:** Takes a captured image and performs OCR using Apple's `Vision` framework. Returns the raw text recognition results (including text strings and potentially bounding boxes).
    * **Sub-components:** Vision Request Handler executing `VNRecognizeTextRequest`.

**1.4. High-Level Data and Control Flow:**

The user initiates the process from the `WelcomeView`. The Coordinator presents the `CameraView`. Upon image capture, the Coordinator receives the `UIImage`. It triggers the `Core Extraction Service` (showing a processing indicator via the UI Layer). The Extraction Service returns results (e.g., `[VNRecognizedTextObservation]`). The Coordinator passes these results to the `ResultsView` within the UI Layer for display.

**1.5. Potential Future Extensions (Out of Scope for this Design):**
While this design focuses on the simple flow, future work could build upon it by adding: image preprocessing (deskewing, enhancement), intelligent text parsing (extracting specific fields like names/IDs), data validation, form integration, real-time camera feed analysis, context awareness, and more robust error handling.

---

## Part 2: Detailed Design Document (Simplified Vision)

This section provides more specific design details for the components of the simplified image-to-text application.

**2.1. Presentation Layer:**
* **UI Framework:** SwiftUI.
* **Views:**
    * `WelcomeView`: The initial view. Contains a title/welcome message and a `Button` ("Start Scan") to initiate the process. Might use `@State` to control navigation/presentation of the camera view.
    * `CameraView`: Presents the camera interface. For the POC, using `UIImagePickerController` wrapped in `UIViewControllerRepresentable` is the simplest approach. Includes necessary delegate handling. Alternatively, a custom view using `AVFoundation` could be built but adds complexity. Should display a header "Capture photo".
    * `ProcessingIndicatorView`: A simple view (potentially an overlay or replacing the CameraView temporarily) showing a `ProgressView` spinner or text like "Processing...". Its visibility controlled by `@State`.
    * `ResultsView`: Displays the outcome. Shows the captured image (optional, for context). Shows a `List` or `ScrollView` containing `Text` views for each raw text string extracted. Optionally displays bounding box overlays on the image. Takes the captured `UIImage` and `[VNRecognizedTextObservation]` as input.
* **State Management:** Primarily using `@State` variables within the main view (`ContentView` or potentially separate views if navigation is used) to manage the captured image, vision results, and the current phase of the process (welcoming, capturing, processing, showing results). Navigation can be handled using `.sheet`, `.fullScreenCover`, or `NavigationLink` depending on the desired flow.

**2.2. Application Logic & Coordination Layer:**
* **Responsibilities:** Handle the `showingImagePicker` state (or similar state for navigation). Receive the captured image from the `CameraView` delegate. Trigger the `Core Extraction Service`. Update state variables to show/hide the `ProcessingIndicatorView`. Pass the results to the `ResultsView`.
* **Implementation:** Can be largely managed within the main SwiftUI View (`ContentView`) using `@State` and helper functions for the POC's simplicity. More complex apps might introduce dedicated `ObservableObject` ViewModels or Coordinator patterns.

**2.3. Capture Service (Simplified):**
* **Technology:** `UIImagePickerController` wrapped using `UIViewControllerRepresentable`.
* **Implementation:** Requires creating the representable struct, implementing its `makeUIViewController`, `updateUIViewController`, and `Coordinator` with `UIImagePickerControllerDelegate` methods (`didFinishPickingMediaWithInfo`, `imagePickerControllerDidCancel`) to receive the `UIImage` or cancellation signal and dismiss the picker.

**2.4. Core Extraction Service (Simplified):**
* **Technology:** Apple `Vision` framework.
* **Implementation:** A function (e.g., `performVisionRequest(on image: UIImage, completion: @escaping ([VNRecognizedTextObservation]?, Error?) -> Void)`) that:
    1. Takes a `UIImage` as input.
    2. Gets the `CGImage`.
    3. Dispatches to a background queue (`DispatchQueue.global().async`).
    4. Creates `VNImageRequestHandler`.
    5. Creates `VNRecognizeTextRequest` with a completion handler. Set `recognitionLevel = .accurate`.
    6. The completion handler dispatches back to the main queue (`DispatchQueue.main.async`) and calls the outer function's completion handler with the results (`[VNRecognizedTextObservation]`) or error.
    7. Performs the request using the handler within a `do-catch` block.

**2.5. Data Flow:**
`Button Tap` -> `Present CameraView (UIImagePickerController)` -> `User Captures Image` -> `Delegate returns UIImage` -> `Trigger Processing Indicator UI` -> `Call Core Extraction Service (background thread)` -> `Vision returns [VNRecognizedTextObservation]` -> `Update Results State (main thread)` -> `Hide Processing Indicator UI` -> `Display ResultsView UI`.

**2.6. Threading Model:**
* UI remains on the Main Thread.
* Vision processing (`VNRecognizeTextRequest`) occurs on a Background Thread via `DispatchQueue.global().async`.
* Result handling and subsequent UI state updates occur back on the Main Thread via `DispatchQueue.main.async`.

---

## Part 3: Proof of Concept (POC) - Implementation Plan (Simplified Flow)

This section provides a step-by-step guide for building the simplified POC application. Each step builds directly on the previous one.

**Goal:** Create an app with: Welcome Screen -> Camera Capture Screen -> Processing Indicator -> Results Screen (showing raw extracted text).

**Technology:** Swift, SwiftUI, Vision, UIImagePickerController.

---

### Step 1: Welcome Screen & Navigation Setup

* **1.A: Functional Requirements:**
    * FR1.1: The app must launch to a "Welcome" screen.
    * FR1.2: The Welcome screen must display a title or welcome message.
    * FR1.3: The Welcome screen must have a button labeled "Start Scan".
    * FR1.4: Tapping the "Start Scan" button must trigger the presentation of the next screen (Camera Screen).
* **1.B: Non-Functional Requirements:**
    * NFR1.1: The UI must use SwiftUI.
    * NFR1.2: State variables must be used to control the presentation of the Camera screen.
* **1.C: Technical Design & Implementation:**
    1.  **Project Setup:** Ensure the Xcode project (`ImageToFormPOC`) is set up as described in Step 0 of the previous detailed plan (including `Info.plist` camera description, `.gitignore`, deployment target).
    2.  **ContentView Structure:** Open `ContentView.swift`. This will serve as our main container and potentially the Welcome screen initially.
    3.  **State for Presentation:** Add a state variable to control showing the camera/image picker:
        ```swift
        // Inside struct ContentView: View { ... }
        @State private var showCamera = false // Controls presenting the camera view
        // Also keep state for results later
        @State private var capturedImage: UIImage? = nil
        @State private var visionResults: [VNRecognizedTextObservation] = []
        ```
    4.  **Welcome UI:** Design the body of `ContentView` to show the welcome elements:
        ```swift
        // Inside var body: some View { ... }
        VStack {
            Spacer() // Push content to center
            Text("Image Text Scanner POC")
                .font(.largeTitle)
                .padding()
            Text("Tap 'Start Scan' to capture an image and extract text.")
                .multilineTextAlignment(.center)
                .padding()
            Spacer() // Push button to bottom or use more spacers
            Button("Start Scan") {
                // Clear previous results when starting a new scan
                self.capturedImage = nil
                self.visionResults = []
                // Set state to true to trigger the sheet/navigation
                self.showCamera = true
            }
            .padding()
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        // Add modifier to present the camera view (implemented next)
        .fullScreenCover(isPresented: $showCamera) { // Use fullScreenCover for camera
             // Placeholder for Camera View (Step 2)
             Text("Camera View Goes Here")
        }
        ```
        *Note: Using `.fullScreenCover` is often better for camera views than `.sheet`.*
    5.  **Verification:** Build and run (Cmd+R). The app should display the welcome text and the "Start Scan" button. Tapping the button should present a full-screen modal view with the placeholder text "Camera View Goes Here". Dismiss this modal (may require a swipe down gesture depending on exact presentation context later).

---

### Step 2: Camera Screen & Image Capture

* **2.A: Functional Requirements:**
    * FR2.1: When triggered (by `showCamera` becoming true), the app must present the camera interface.
    * FR2.2: The camera interface should have a clear header or title like "Capture photo".
    * FR2.3: The user must be able to capture a photo or cancel.
    * FR2.4: Upon capture, the `UIImage` must be obtained.
    * FR2.5: The camera view must be dismissed after capture or cancellation.
    * FR2.6: The captured image must be stored for processing.
* **2.B: Non-Functional Requirements:**
    * NFR2.1: Use `UIImagePickerController` wrapped in `UIViewControllerRepresentable` for simplicity.
    * NFR2.2: Handle camera/library permissions implicitly via the picker.
    * NFR2.3: Use `@Binding` to pass the captured image back.
    * NFR2.4: Use `@Environment(\.presentationMode)` to dismiss the view.
* **2.C: Technical Design & Implementation:**
    1.  **Create `ImagePicker.swift`:** Create a new Swift file `ImagePicker.swift`.
    2.  **Implement `ImagePicker`:** Add the `UIViewControllerRepresentable` code from the *previous response's* Step 2.C (or Step 3.C of *this* document's POC Plan Part 3). **Crucially:**
        * It needs `@Binding var selectedImage: UIImage?`.
        * It needs the `Coordinator` class implementing the delegate methods.
        * The `didFinishPickingMediaWithInfo` delegate method should assign the image to `parent.selectedImage` and call `parent.presentationMode.wrappedValue.dismiss()`. **Do not call `processImage` yet**.
        * The `imagePickerControllerDidCancel` should just call `parent.presentationMode.wrappedValue.dismiss()`.
        * `makeUIViewController` should set up the `UIImagePickerController`, set the delegate, and choose `.camera` or `.photoLibrary` source type.
    3.  **Add Header (Simple Approach):** Since `UIImagePickerController` doesn't easily allow custom headers, we'll skip adding the "Capture photo" header *within the picker itself* for this simple POC using the standard picker. The context shift implies capture.
    4.  **Connect in `ContentView`:** In `ContentView.swift`, replace the placeholder `Text` inside the `.fullScreenCover` modifier with the actual `ImagePicker`, passing the binding:
        ```swift
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(selectedImage: $capturedImage) // Pass binding for image
        }
        ```
        *Note: We removed the `visionResults` binding here as processing isn't triggered directly by the picker anymore in this revised flow.*
    5.  **Verification:** Build and run. Tap "Start Scan". The camera/photo library should appear. Select/take a photo and confirm. The view should dismiss. Cancel the picker. The view should dismiss. The welcome screen won't show the image yet.

---

### Step 3: Processing Indicator & Vision Task

* **3.A: Functional Requirements:**
    * FR3.1: After the camera dismisses with a captured image, the app must indicate that processing is occurring.
    * FR3.2: The app must initiate the Vision OCR task on the captured image.
    * FR3.3: The processing indicator must disappear once OCR is complete.
    * FR3.4: The OCR results (`[VNRecognizedTextObservation]`) must be stored.
* **3.B: Non-Functional Requirements:**
    * NFR3.1: Processing indicator should overlay the UI or be presented modally.
    * NFR3.2: Vision task must run on a background thread.
    * NFR3.3: State updates (showing/hiding indicator, storing results) must happen on the main thread.
    * NFR3.4: Use `VNRecognizeTextRequest` with `.accurate` level.
* **3.C: Technical Design & Implementation:**
    1.  **State for Processing:** In `ContentView.swift`, add a new state variable:
        ```swift
        @State private var isProcessing = false // Controls showing the indicator
        ```
    2.  **Trigger Processing:** Modify the `.fullScreenCover` in `ContentView`. We need to know when an image *is* selected. A simple way is using `.onChange(of: capturedImage)`:
        ```swift
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(selectedImage: $capturedImage)
        }
        // Add this modifier to react when an image is picked
        .onChange(of: capturedImage) { newImage in
            if let image = newImage {
                // Image selected! Start processing.
                isProcessing = true // Show indicator
                performVisionRequest(on: image) // Call Vision function
            }
        }
        // Add an overlay for the processing indicator
        .overlay { // Use overlay to show indicator on top
            if isProcessing {
                // Simple indicator view
                ZStack {
                    // Semi-transparent background
                    Color(white: 0, opacity: 0.5).edgesIgnoringSafeArea(.all)
                    // Spinner
                    ProgressView("Processing...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                }
            }
        }
        ```
    3.  **Create `performVisionRequest` Function:** Add this function *inside* the `ContentView` struct:
        ```swift
        func performVisionRequest(on image: UIImage) {
            guard let cgImage = image.cgImage else {
                print("Failed to get CGImage")
                isProcessing = false // Hide indicator on error
                return
            }

            print("Starting Vision processing on background thread...")
            // Run Vision on background thread
            DispatchQueue.global(qos: .userInitiated).async {
                let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                let textRequest = VNRecognizeTextRequest { (request, error) in
                    // Process results on main thread
                    DispatchQueue.main.async {
                        print("Vision processing finished.")
                        // Hide indicator *before* potential navigation
                        isProcessing = false

                        if let error = error {
                            print("Vision Error: \(error.localizedDescription)")
                            self.visionResults = [] // Clear results on error
                            // Optionally navigate to Results screen even on error,
                            // or show an alert here. For simplicity, we'll proceed.
                            // Consider adding state to show error on Results screen.
                            return // Exit completion handler
                        }
                        guard let observations = request.results as? [VNRecognizedTextObservation] else {
                            print("Could not cast Vision results.")
                            self.visionResults = []
                            // Proceed to Results screen, which will show "no text found"
                            return // Exit completion handler
                        }
                        print("Vision success: Found \(observations.count) observations.")
                        self.visionResults = observations
                        // NOTE: Navigation/transition to Results screen will be handled
                        // based on changes to visionResults or another state variable if needed.
                        // For now, results are stored, indicator hides.
                    }
                }
                textRequest.recognitionLevel = .accurate
                textRequest.usesLanguageCorrection = true

                do {
                    try requestHandler.perform([textRequest])
                } catch {
                    DispatchQueue.main.async {
                        print("Failed to perform Vision request: \(error.localizedDescription)")
                        self.visionResults = []
                        isProcessing = false // Hide indicator on error
                    }
                }
            }
        }
        ```
    4.  **Verification:** Build and run. Tap "Start Scan", capture/select an image. After the picker dismisses, a semi-transparent overlay with a "Processing..." spinner should appear briefly. Check the console logs for the "Vision success..." or error messages. The results aren't displayed yet.

---

### Step 4: Results Display Screen

* **4.A: Functional Requirements:**
    * FR4.1: Display the list of raw text strings extracted by Vision.
    * FR4.2: Optionally display the captured image for context.
    * FR4.3: Optionally display bounding boxes over the image.
    * FR4.4: Provide a way to return to the Welcome screen (e.g., a back button if using Navigation, or a dismiss button).
* **4.B: Non-Functional Requirements:**
    * NFR4.1: The results screen should appear after processing finishes.
    * NFR4.2: Use SwiftUI for the UI.
    * NFR4.3: Display should handle the case where no text was found.
* **4.C: Technical Design & Implementation:**
    1.  **Integrate Results Display in `ContentView`:** For this simplified POC, instead of a separate screen, we can reuse `ContentView` and conditionally show results *instead* of the Welcome message once an image has been processed. Modify the `ContentView`'s main `VStack` structure:
        ```swift
        NavigationView { // Keep NavigationView for title and potential back button
            VStack {
                // Conditionally show Welcome OR Results
                if capturedImage == nil {
                    // --- Welcome View Content ---
                    Spacer()
                    Text("Image Text Scanner POC").font(.largeTitle).padding()
                    Text("Tap 'Start Scan' to capture an image and extract text.").multilineTextAlignment(.center).padding()
                    Spacer()
                    Button("Start Scan") {
                        self.capturedImage = nil
                        self.visionResults = []
                        self.showCamera = true
                    }
                    .padding().buttonStyle(.borderedProminent)
                    Spacer()
                    // --- End Welcome View ---
                } else {
                    // --- Results View Content ---
                    Text("Scan Results").font(.headline).padding(.top) // Header for results

                    ZStack { // Use ZStack for image and overlay
                         if let image = capturedImage {
                              Image(uiImage: image)
                                   .resizable()
                                   .scaledToFit()
                                   // Apply the overlay using the state variable
                                   .overlay(BoundingBoxOverlay(observations: visionResults))
                         } else {
                              // Should ideally not happen if capturedImage is not nil, but fallback
                              Text("Error displaying image.")
                         }
                    }
                    .frame(minHeight: 150, maxHeight: 300) // Adjust size for results view
                    .border(Color.gray, width: 1)
                    .padding([.leading, .trailing, .bottom])

                    List { // Display text results
                         Section("Extracted Text:") {
                              if visionResults.isEmpty && !isProcessing { // Check !isProcessing
                                   Text("Processing complete. No text found.")
                                      .foregroundColor(.gray)
                              } else if isProcessing {
                                   Text("Processing...") // Should be covered by overlay, but good fallback
                                      .foregroundColor(.gray)
                              } else {
                                   ForEach(visionResults, id: \.uuid) { observation in
                                        Text(observation.topCandidates(1).first?.string ?? "Error reading text")
                                   }
                              }
                         }
                    }
                    .listStyle(InsetGroupedListStyle())
                    // --- End Results View ---
                }
            } // End main VStack
            .navigationTitle(capturedImage == nil ? "Welcome" : "Scan Results") // Dynamic title
            .navigationBarTitleDisplayMode(.inline)
            // Add a ToolbarItem if needed to explicitly go back or rescan
            .toolbar {
                if capturedImage != nil { // Show only on results view
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Scan New") {
                            // Reset state to go back to welcome/trigger new scan
                            self.capturedImage = nil
                            self.visionResults = []
                            self.showCamera = true // Show camera immediately
                        }
                    }
                }
            }
            // Keep the sheet and overlay modifiers from before
            .fullScreenCover(isPresented: $showCamera) {
                 ImagePicker(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { newImage in
                 if let image = newImage {
                      isProcessing = true
                      performVisionRequest(on: image)
                 }
            }
            .overlay {
                 if isProcessing {
                      ZStack {
                           Color(white: 0, opacity: 0.5).edgesIgnoringSafeArea(.all)
                           ProgressView("Processing...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .foregroundColor(.white).padding().background(Color.black.opacity(0.7)).cornerRadius(10)
                      }
                 }
            }
        } // End NavigationView
        ```
    2.  **Implement `BoundingBoxOverlay`:** Ensure the `BoundingBoxOverlay.swift` file exists and contains the code from the *previous response's* Step 6.C (including `import SwiftUI`, `import Vision`, the struct definition, `GeometryReader`, the coordinate calculations, and drawing the `Rectangle().stroke(...)`).
    3.  **Verification:** Build and run. The app starts at the Welcome screen. Tap "Start Scan", capture/select an image with text. The processing indicator shows. Then, the view should change to "Scan Results", showing the image, the red bounding boxes over detected text, and the list of extracted text strings below. Tap the "Scan New" button in the top-left; it should present the camera again, and upon capturing a new image, show the new results.
