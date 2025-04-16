//
//  MeterReadingView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Import Vision framework
import CoreGraphics // For CGImagePropertyOrientation

// Ensure Deployment Target is iOS 18.0+

struct MeterReadingView: View {
    // MARK: - State Variables specific to this view
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var visionResults: [RecognizedTextObservation] = [] // Holds OCR results
    @State private var isProcessing = false

    var body: some View {
        VStack {
            // Area to display results (initially empty)
            List {
                Section("Extracted Text from Meter:") {
                    if isProcessing {
                        HStack {
                            Spacer()
                            ProgressView() // Show simple spinner inline while processing
                            Spacer()
                        }
                    } else if visionResults.isEmpty {
                        Text(capturedImage == nil ? "Tap 'Scan Meter' below." : "No text detected.")
                            .foregroundColor(.gray)
                    } else {
                        // Display raw text results
                        ForEach(visionResults, id: \.uuid) { observation in // Assumes .uuid
                            // Assumes .topCandidates exists on new type
                            Text(observation.topCandidates(1).first?.string ?? "Read Error")
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            // Optionally show the captured image for reference
            // if let image = capturedImage {
            //     Image(uiImage: image)
            //         .resizable().scaledToFit().frame(height: 150)
            // }

            Spacer() // Pushes button to bottom

            // Button to start the scan for this feature
            Button {
                self.visionResults = [] // Clear previous results
                self.capturedImage = nil // Clear previous image
                self.showCamera = true  // Trigger sheet presentation
            } label: {
                Label("Scan Meter", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()

        } // End main VStack
        .navigationTitle("Read Meter") // Set title for this screen

        // Modifier to present the ImagePicker
        // Using .sheet here, but .fullScreenCover is also fine
        .sheet(isPresented: $showCamera) {
            // Re-use ImagePicker, passing binding for the captured image
            ImagePicker(selectedImage: $capturedImage)
        }
        // Modifier to trigger processing when a new image is captured
        .onChange(of: capturedImage) { _, newImage in // iOS 17+ signature
            if let image = newImage {
                print("MeterReadingView: onChange detected new image. Launching processing Task.")
                // Launch Task to perform async Vision processing
                Task {
                    // Set processing state ON (MainActor implicitly via @State update)
                    isProcessing = true
                    // Call the local async function to perform OCR
                    await performVisionRequest(on: image)
                    // Set processing state OFF (MainActor implicitly)
                    isProcessing = false
                }
            }
        }
        // Modifier to show overlay while processing (optional, List shows inline spinner)
        // .overlay { if isProcessing { ProcessingIndicatorView() } }

    } // End body

    // MARK: - Vision Processing Function (Adapted for this view)

    /// Performs text recognition using the new Vision API (`RecognizeTextRequest`).
    /// Updates the local `visionResults` state variable.
    @MainActor // Ensure state updates run safely on the main actor
    private func performVisionRequest(on image: UIImage) async {
        guard let cgImage = image.cgImage else {
            print("MeterReadingView Error: Failed to get CGImage.")
            // isProcessing is set false by the calling Task
            return
        }

        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("MeterReadingView DEBUG: Using CGImagePropertyOrientation: \(imageOrientation.rawValue)")
        print("MeterReadingView: Starting Vision Text Recognition (New API)...")

        // --- Prepare Text Recognition Request ---
        var textRequest = RecognizeTextRequest() // Use new struct, make VAR
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true // Keep enabled, might help with numbers if noisy

        // --- Perform Request using async/await ---
        do {
            // No separate handler needed for new API's perform method
            print("MeterReadingView: Performing RecognizeTextRequest directly...")
            let results: [RecognizedTextObservation] = try await textRequest.perform(
                on: cgImage,
                orientation: imageOrientation
            )

            // Success: Update local state directly (we are on @MainActor)
            print("MeterReadingView OCR success: Found \(results.count) observations.")
            self.visionResults = results

        } catch {
            // Handle errors performing the request
            print("MeterReadingView Error: Failed to perform Vision request: \(error.localizedDescription)")
            self.visionResults = [] // Clear results on error
        }
        // --- End Perform Request ---

        // isProcessing = false is handled by the calling Task after await returns/throws
        print("MeterReadingView: Vision processing function finished.")
    } // End performVisionRequest


    // --- Orientation Helper (Copied from ContentView) ---
    // Keep this helper function within MeterReadingView as well
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
            @unknown default: print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up"); return .up
         }
    }

} // End MeterReadingView struct

// MARK: - Preview
#Preview {
    // Embed in NavigationView for previewing navigation title
    NavigationView {
        MeterReadingView()
    }
}
