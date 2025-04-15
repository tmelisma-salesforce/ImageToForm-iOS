//
//  ContentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Use Vision framework
import CoreGraphics // Import for CGImagePropertyOrientation

// Ensure Deployment Target is iOS 18.0+ for this API

struct ContentView: View {

    // MARK: - State Variables
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    // Use the new Observation struct type (Assumption: It exists and has needed props)
    @State private var visionResults: [RecognizedTextObservation] = []
    @State private var isProcessing = false
    // Classification state removed

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack {
                // Conditional View: Welcome OR Results
                if capturedImage == nil {
                    WelcomeView(
                        showCamera: $showCamera,
                        capturedImage: $capturedImage,
                        visionResults: $visionResults
                    )
                } else {
                    ResultsView(
                        capturedImage: $capturedImage,
                        visionResults: $visionResults,
                        isProcessing: $isProcessing,
                        showCamera: $showCamera
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
                ImagePicker(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { _, newImage in // iOS 17+ signature
                if let image = newImage {
                    print("onChange detected new image. Launching processing Task.")
                    // Launch Swift Concurrency Task to handle async work
                    Task {
                        // Set processing state ON the Main Actor before starting async work
                        await MainActor.run {
                            isProcessing = true
                        }
                        // Call the async function
                        await performVisionRequest(on: image)
                        // Set processing state OFF on the Main Actor after async work finishes
                        await MainActor.run {
                            isProcessing = false
                        }
                    }
                } else {
                    print("onChange detected image became nil (likely reset).")
                }
            }
            .overlay {
                if isProcessing {
                    ProcessingIndicatorView()
                }
            }

        } // End NavigationView
        .navigationViewStyle(.stack)
    } // End body

    // MARK: - Helper Functions

    private func resetScan() {
        print("Resetting scan state.")
        self.capturedImage = nil
        self.visionResults = []
    }

    // MARK: - Vision Processing Function (Using NEW Swift-only API - CORRECTED)

    /// Performs text recognition using the new Vision API (`RecognizeTextRequest`).
    @MainActor // Ensure state updates run on the main actor
    private func performVisionRequest(on image: UIImage) async { // Function is async
        guard let cgImage = image.cgImage else {
            print("Error: Failed to get CGImage from input UIImage.")
            // isProcessing is set false by the calling Task
            return
        }

        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("DEBUG: Using CGImagePropertyOrientation: \(imageOrientation.rawValue)")

        print("Starting Vision Text Recognition (New API)...")

        // --- Prepare Text Recognition Request ---
        // 1. Create the request struct using VAR to allow modification
        var textRequest = RecognizeTextRequest() // <-- Changed LET to VAR

        // 2. Configure optional properties on the mutable struct instance
        textRequest.recognitionLevel = .accurate // Now assignable
        textRequest.usesLanguageCorrection = true // Now assignable
        // --- End Request Setup ---


        // --- Perform Request using async/await ---
        do {
            // 3. Call perform() DIRECTLY on the request struct instance.
            //    No separate VNImageRequestHandler object is needed for this API pattern.
            print("Performing RecognizeTextRequest directly...")
            let results: [RecognizedTextObservation] = try await textRequest.perform(
                on: cgImage,
                orientation: imageOrientation
            )

            // 4. Success: Update state directly (we are already on @MainActor)
            print("OCR success: Found \(results.count) observations.")
            self.visionResults = results

        } catch {
            // 5. Handle errors performing the request
            print("Error: Failed to perform Vision request: \(error.localizedDescription)")
            self.visionResults = [] // Clear results on error
        }
        // --- End Perform Request ---

        // isProcessing = false is handled by the calling Task after await returns/throws
        print("Vision processing function finished.")
    } // End performVisionRequest


    // --- Orientation Helper (Unchanged) ---
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored
            @unknown default: print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up"); return .up
         }
    }

} // End ContentView

// MARK: - Subviews (Bindings Updated)

struct WelcomeView: View {
    // Only needs bindings relevant to resetting state and showing camera
    @Binding var showCamera: Bool
    @Binding var capturedImage: UIImage?
    @Binding var visionResults: [RecognizedTextObservation] // Use NEW type

    var body: some View {
        VStack {
            Spacer()
            Text("Image Text Scanner POC").font(.largeTitle).padding(.bottom, 5)
            Text("Tap 'Start Scan' to capture an image and extract text.").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding([.leading, .trailing])
            Spacer()
            Button("Start Scan") {
                // Reset relevant states
                self.capturedImage = nil
                self.visionResults = []
                self.showCamera = true
            }
            .padding().buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

struct ResultsView: View {
    // Only needs bindings relevant to displaying results
    @Binding var capturedImage: UIImage?
    @Binding var visionResults: [RecognizedTextObservation] // Use NEW type
    @Binding var isProcessing: Bool // Needed to show correct list state
    @Binding var showCamera: Bool // Passed through but not used directly

    var body: some View {
        VStack {
            // Classification Text removed

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

            List {
                Section("Extracted Text:") {
                    if visionResults.isEmpty && !isProcessing {
                         Text("Processing complete. No text found.")
                            .foregroundColor(.gray)
                    } else if isProcessing { // Should be covered by overlay
                         Text("Processing...")
                            .foregroundColor(.gray)
                    } else {
                         ForEach(visionResults, id: \.uuid) { observation in // Assumes .uuid exists
                             // Assumes .topCandidates exists on new type
                             Text(observation.topCandidates(1).first?.string ?? "Read Error")
                         }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
}

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
    ContentView()
}
