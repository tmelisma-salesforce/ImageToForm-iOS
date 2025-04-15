//
//  ContentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision
import CoreML
import CoreGraphics

// Ensure Deployment Target is iOS 18.0+

struct ContentView: View {

    // MARK: - State Variables
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var visionResults: [RecognizedTextObservation] = []
    @State private var isProcessing = false
    @State private var classificationLabel: String = ""
    @State private var showingClassificationAlert = false
    @State private var classificationAlertMessage = ""

    // Define allowed classification identifiers
    private let allowedClassifications: Set<String> = [
        "binder", "ring-binder", "menu", "envelope", "letter",
        "document", "paper", "text", "label"
    ]

    // MARK: - Main Body
    var body: some View {
        NavigationView {
            mainContent // Use extracted view
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
                .onChange(of: capturedImage) { _, newImage in
                    if let image = newImage {
                        print("onChange detected new image. Launching processing Task.")
                        Task {
                            await MainActor.run { isProcessing = true }
                            await performVisionRequests(on: image)
                            // isProcessing is set false inside performVisionRequests now
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
                .alert("Classification Result", isPresented: $showingClassificationAlert) {
                    Button("OK") { }
                } message: {
                    Text(classificationAlertMessage)
                }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - Extracted Main Content View (UPDATED CALL to ResultsView)
    @ViewBuilder
    private var mainContent: some View {
        VStack {
            if capturedImage == nil {
                WelcomeView(
                    showCamera: $showCamera,
                    capturedImage: $capturedImage,
                    visionResults: $visionResults,
                    classificationLabel: $classificationLabel
                )
            } else {
                // *** REMOVED showCamera argument from this call ***
                ResultsView(
                    capturedImage: $capturedImage,
                    visionResults: $visionResults,
                    isProcessing: $isProcessing,
                    classificationLabel: $classificationLabel
                )
            }
        }
    }

    // MARK: - Helper Functions (Unchanged from previous step)
    // resetScan()
    // performVisionRequests()
    // performClassification()
    // performOCR()
    // cgOrientation()
    // ... (keep the full implementations of these functions as provided before) ...

    // NOTE: For brevity, the helper functions are not repeated here,
    // but ensure they remain exactly as provided in the previous response.
    // Specifically, keep the full 'performVisionRequests' and its helper async functions.

    /// Resets state variables for a new scan.
    private func resetScan() {
        print("Resetting scan state.")
        self.capturedImage = nil
        self.visionResults = []
        self.classificationLabel = "" // Reset classification
    }

    /// Performs Image Classification (ResNet50) and Text Recognition using the new async Vision API.
    @MainActor
    private func performVisionRequests(on image: UIImage) async {
        guard let cgImage = image.cgImage else {
            print("Error: Failed to get CGImage from input UIImage.")
            isProcessing = false // Ensure indicator stops
            return
        }

        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("DEBUG: Using CGImagePropertyOrientation: \(imageOrientation.rawValue)")
        print("Starting Vision processing (Classification + OCR - New API)...")

        self.visionResults = []
        self.classificationLabel = ""

        let classificationRequest: CoreMLRequest
        do {
            let coreMLModel = try Resnet50(configuration: MLModelConfiguration()).model
            let container = try CoreMLModelContainer(model: coreMLModel, featureProvider: nil)
            classificationRequest = CoreMLRequest(model: container)
            print("DEBUG: ResNet50 model loaded and CoreMLRequest created.")
        } catch {
            print("Error preparing classification request: \(error)")
            self.classificationLabel = "Model Load Error"
            isProcessing = false
            return
        }

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        var classificationOutcome: String? = nil
        var classificationError: Error? = nil
        var ocrError: Error? = nil

        do {
            print("Performing Classification and Text requests concurrently...")
            async let classificationTask: () = performClassification(request: classificationRequest, on: cgImage, orientation: imageOrientation, label: &classificationOutcome, error: &classificationError)
            async let ocrTask: () = performOCR(request: textRequest, on: cgImage, orientation: imageOrientation, error: &ocrError)
            _ = try await [classificationTask, ocrTask]
            print("Both Vision tasks completed.")
        } catch {
            print("Error performing Vision requests group: \(error.localizedDescription)")
            if classificationOutcome == nil { classificationLabel = "Processing Error" }
            if visionResults.isEmpty { self.visionResults = [] }
        }

        // Validation Logic
        if let error = classificationError {
             print("Classification task failed with error: \(error.localizedDescription)")
             self.classificationLabel = "Classification Error"
        } else if let label = classificationOutcome {
            let topIdentifier = label.components(separatedBy: " (").first ?? label
            print("Top classification identifier: \(topIdentifier)")
            if allowedClassifications.contains(topIdentifier.lowercased()) {
                print("Classification SUCCESS: '\(topIdentifier)' is in the allowed list.")
                self.classificationLabel = label
            } else {
                print("Classification REJECTED: '\(topIdentifier)' is not in allowed list.")
                self.classificationLabel = "Incorrect Item (\(topIdentifier))"
                self.classificationAlertMessage = "I'm sorry but that doesn't look like an expected document. That looks like a '\(topIdentifier)'."
                self.showingClassificationAlert = true
            }
        } else {
             print("Classification produced no identifiable result.")
             self.classificationLabel = "Classification Failed"
        }

        if let error = ocrError {
            print("OCR task failed with error: \(error.localizedDescription)")
        }

        print("Setting isProcessing = false")
        isProcessing = false // Hide indicator now

    } // End performVisionRequests

    // --- Async Helper for Classification ---
    @MainActor
    private func performClassification(request: CoreMLRequest, on cgImage: CGImage, orientation: CGImagePropertyOrientation, label: inout String?, error: inout Error?) async {
        do {
            let observations: [any VisionObservation] = try await request.perform(on: cgImage, orientation: orientation)
            let classificationObservations = observations.compactMap { $0 as? ClassificationObservation }
            if let topResult = classificationObservations.first {
                label = "\(topResult.identifier) (\(String(format: "%.0f%%", topResult.confidence * 100)))"
                print("Classification helper success: \(label ?? "N/A")")
            } else {
                print("Classification helper returned no results.")
                label = "No classification result"
            }
        } catch let classificationError {
            print("Classification helper Error: \(classificationError.localizedDescription)")
            error = classificationError
            label = "Classification Error"
        }
    }

    // --- Async Helper for OCR ---
    @MainActor
    private func performOCR(request: RecognizeTextRequest, on cgImage: CGImage, orientation: CGImagePropertyOrientation, error: inout Error?) async {
         do {
             let results: [RecognizedTextObservation] = try await request.perform(on: cgImage, orientation: orientation)
             print("OCR helper success: Found \(results.count) observations.")
             self.visionResults = results
         } catch let ocrError {
             print("OCR helper Error: \(ocrError.localizedDescription)")
             error = ocrError
             self.visionResults = []
         }
    }

    // --- Orientation Helper ---
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
            @unknown default: print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up"); return .up
         }
    }

} // End ContentView

// MARK: - Preview
#Preview {
    ContentView()
}
