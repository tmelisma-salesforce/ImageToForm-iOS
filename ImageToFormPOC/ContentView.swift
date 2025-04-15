//
//  ContentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Use Vision framework
import CoreML  // Import CoreML for loading the model
import CoreGraphics // For CGImagePropertyOrientation

// Ensure Deployment Target is iOS 18.0+ for this API

struct ContentView: View {

    // MARK: - State Variables
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var visionResults: [RecognizedTextObservation] = [] // NEW Observation Type
    @State private var isProcessing = false
    @State private var classificationLabel: String = "" // State for classification

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack {
                // Conditionally show Welcome OR Results
                if capturedImage == nil {
                    WelcomeView(
                        showCamera: $showCamera,
                        capturedImage: $capturedImage,
                        visionResults: $visionResults,
                        classificationLabel: $classificationLabel // Pass binding
                    )
                } else {
                    ResultsView(
                        capturedImage: $capturedImage,
                        visionResults: $visionResults,
                        isProcessing: $isProcessing,
                        showCamera: $showCamera, // Still needed for potential reset logic within ResultsView if refactored
                        classificationLabel: $classificationLabel // Pass binding
                    )
                }
            }
            .navigationTitle(capturedImage == nil ? "Welcome" : "Scan Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if capturedImage != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Scan New") {
                            resetScan()
                        }
                    }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                // ImagePicker returns the selected UIImage via the binding
                ImagePicker(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newImage in // iOS 17+ signature
                if let image = newImage {
                    print("onChange detected new image. Launching processing Task.")
                    // Launch Swift Concurrency Task to handle async Vision work
                    Task {
                        // Set processing state ON the Main Actor before starting
                        await MainActor.run { isProcessing = true }
                        // Perform the combined async Vision requests
                        await performVisionRequests(on: image)
                        // Set processing state OFF on the Main Actor after finishing
                        await MainActor.run { isProcessing = false }
                    }
                } else {
                    print("onChange detected image became nil (likely reset).")
                }
            }
            .overlay {
                // Show processing indicator while busy
                if isProcessing {
                    ProcessingIndicatorView()
                }
            }

        } // End NavigationView
        .navigationViewStyle(.stack)
    } // End body

    // MARK: - Helper Functions

    /// Resets state for a new scan.
    private func resetScan() {
        print("Resetting scan state.")
        self.capturedImage = nil
        self.visionResults = []
        self.classificationLabel = "" // Reset classification
    }

    // MARK: - Vision Processing Function (NEW API - async/await, Classification + OCR)

    /// Performs Image Classification (ResNet50) and Text Recognition using the new async Vision API.
    @MainActor // Ensures state updates run safely on the main actor
    private func performVisionRequests(on image: UIImage) async {
        guard let cgImage = image.cgImage else {
            print("Error: Failed to get CGImage from input UIImage.")
            // isProcessing handled by calling Task
            return
        }

        // Determine image orientation for Vision requests
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("DEBUG: Using CGImagePropertyOrientation: \(imageOrientation.rawValue)")

        print("Starting Vision processing (Classification + OCR - New API)...")

        // --- Prepare Classification Request using ResNet50 ---
        let classificationRequest: CoreMLRequest // Use the new struct type
        do {
            // Load the MLModel (use non-deprecated init)
            let coreMLModel = try Resnet50(configuration: MLModelConfiguration()).model
            // Create the container required by CoreMLRequest
            let container = try CoreMLModelContainer(model: coreMLModel, featureProvider: nil)
            // Create the CoreMLRequest using the container
            classificationRequest = CoreMLRequest(model: container)
            print("DEBUG: ResNet50 model loaded and CoreMLRequest created.")
        } catch {
            print("Error preparing classification request: \(error)")
            self.classificationLabel = "Model Init Error"
            // Allow OCR to proceed even if classification fails to init
            // but we need a placeholder; alternatively, return here.
            // For now, let OCR run. A real app might handle this better.
             // We need to exit or handle the lack of a valid classificationRequest
             self.visionResults = [] // Clear OCR results too if we bail early
             print("Cannot proceed without classification model.")
             return // Exit if model/container fails
        }
        // --- End Classification Request Prep ---


        // --- Prepare Text Recognition Request ---
        var textRequest = RecognizeTextRequest() // Use the new struct type, make it VAR
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        // --- End Text Recognition Request Prep ---


        // --- Perform Both Requests Concurrently using async let ---
        do {
            print("Performing Classification and Text requests concurrently...")

            // Start both requests asynchronously
            async let classificationTask: () = performClassification(request: classificationRequest, on: cgImage, orientation: imageOrientation)
            async let ocrTask: () = performOCR(request: textRequest, on: cgImage, orientation: imageOrientation)

            // Wait for both tasks to complete
            _ = try await [classificationTask, ocrTask] // Wait for both, ignore void results

            print("Both Vision tasks completed.")

        } catch {
            // Catch errors specifically from the requestHandler.perform calls if they throw
            // or errors re-thrown from the helper async functions
            print("Error performing Vision requests: \(error.localizedDescription)")
            // Set error states if desired
            self.classificationLabel = "Processing Error"
            self.visionResults = []
        }
        // --- End Perform Requests ---

        // isProcessing = false is handled by the calling Task after this function returns/throws
        print("Vision processing function finished.")
    } // End performVisionRequests


    // --- Async Helper for Classification (REVISED) ---
        @MainActor
        private func performClassification(request: CoreMLRequest, on cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws {
            // 1. Perform the request, getting the generic result type
            let observations: [any VisionObservation] = try await request.perform(on: cgImage, orientation: orientation) // Result is Array<any VisionObservation>

            // 2. Filter and cast the results to the specific type we expect
            let classificationObservations = observations.compactMap { observation in
                observation as? ClassificationObservation // Try casting each element
            }
            // Now, 'classificationObservations' is correctly typed as [ClassificationObservation]

            // 3. Process the specifically typed results as before
            if let topResult = classificationObservations.first {
                // Assuming ClassificationObservation has identifier and confidence
                self.classificationLabel = "\(topResult.identifier) (\(String(format: "%.0f%%", topResult.confidence * 100)))"
                print("Classification success: \(self.classificationLabel)")
            } else {
                print("Classification returned no results or results couldn't be cast.")
                self.classificationLabel = "No classification result"
            }
        }
    
    // --- Async Helper for OCR ---
    @MainActor
    private func performOCR(request: RecognizeTextRequest, on cgImage: CGImage, orientation: CGImagePropertyOrientation) async throws {
         let results: [RecognizedTextObservation] = try await request.perform(on: cgImage, orientation: orientation)
         print("OCR success: Found \(results.count) observations.")
         self.visionResults = results // Update state with new observation type
    }


    // --- Orientation Helper (Unchanged) ---
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored
            @unknown default: print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up"); return .up
         }
    }

} // End ContentView

// MARK: - Subviews (Bindings Updated, ResultsView uses new types)

struct WelcomeView: View {
    // Add classification binding to reset it
    @Binding var showCamera: Bool
    @Binding var capturedImage: UIImage?
    @Binding var visionResults: [RecognizedTextObservation] // NEW Type
    @Binding var classificationLabel: String // NEW Binding

    var body: some View {
        VStack {
            Spacer()
            Text("Image Text Scanner POC").font(.largeTitle).padding(.bottom, 5)
            Text("Tap 'Start Scan' to capture an image and extract text.").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding([.leading, .trailing])
            Spacer()
            Button("Start Scan") {
                self.capturedImage = nil
                self.visionResults = []
                self.classificationLabel = "" // Also clear classification
                self.showCamera = true
            }
            .padding().buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

struct ResultsView: View {
    // Add binding for classificationLabel, use new observation type
    @Binding var capturedImage: UIImage?
    @Binding var visionResults: [RecognizedTextObservation] // NEW Type
    @Binding var isProcessing: Bool
    @Binding var showCamera: Bool
    @Binding var classificationLabel: String // NEW Binding

    var body: some View {
        VStack {
            // Display Classification Result First
            Text("Detected: \(classificationLabel.isEmpty ? "N/A" : classificationLabel)")
                 .font(.title3)
                 .padding(.top)
                 .padding(.horizontal)

            // Display Image and Bounding Boxes
            ZStack {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        // Ensure BoundingBoxOverlay uses the new observation type
                        .overlay(BoundingBoxOverlay(observations: visionResults))
                } else {
                    Text("Error displaying image.")
                }
            }
            .frame(minHeight: 150, maxHeight: 300)
            .border(Color.gray, width: 1)
            .padding([.leading, .trailing, .bottom])

            // Display OCR Text List
            List {
                Section("Extracted Text:") {
                    if visionResults.isEmpty && !isProcessing {
                         Text("Processing complete. No text found.")
                            .foregroundColor(.gray)
                    } else if isProcessing {
                         Text("Processing...")
                            .foregroundColor(.gray)
                    } else {
                         // Iterate using new observation type
                         ForEach(visionResults, id: \.uuid) { observation in // Assumes .uuid
                             // *** ASSUMPTION HERE for top text candidate ***
                             Text(observation.topCandidates(1).first?.string ?? "Read Error")
                         }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        } // End Results VStack
    } // End body
} // End ResultsView

// ProcessingIndicatorView remains the same
struct ProcessingIndicatorView: View {
     var body: some View {
        ZStack {
            Color(white: 0, opacity: 0.5).edgesIgnoringSafeArea(.all)
            ProgressView("Processing...")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 10)
        }
    }
}


// MARK: - Preview
#Preview {
    // Ensure preview works, might need to adjust if state causes issues
    ContentView()
}
