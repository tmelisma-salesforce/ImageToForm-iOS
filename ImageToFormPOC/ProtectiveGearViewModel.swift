//
//  ProtectiveGearViewModel.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision
import CoreML
import CoreGraphics
import Accelerate

// Ensure Deployment Target is iOS 18.0+

// Supporting Struct definitions now live in YOLOv8Parser.swift (or own files)
// struct DetectedObject: Identifiable { ... }
// struct AssignableField: Identifiable { ... } // REMOVED FROM HERE
// private struct DetectionCandidate { ... }

@MainActor
class ProtectiveGearViewModel: ObservableObject {

    // MARK: - Published State
    @Published var selfieImage: UIImage? = nil
    @Published var isProcessing = false
    @Published var detectedObjects: [DetectedObject] = [] // Uses struct from Parser file
    @Published var detectionErrorMessage: String? = nil
    @Published var showDetectionPreview = false
    @Published var showFrontCamera = false

    // MARK: - Dependencies
    private let objectParser = YOLOv8Parser() // Create instance of the parser

    // MARK: - Actions from UI
    func checkGearButtonTapped() { resetState(); showFrontCamera = true }

    func imageCaptured(_ image: UIImage?) {
        guard let capturedImage = image else { return }
        self.selfieImage = capturedImage
        Task {
            self.isProcessing = true
            await performObjectDetection(on: capturedImage)
        }
    }

    func retakePhoto() { resetState(clearImage: true); showDetectionPreview = false; showFrontCamera = true }
    func proceedFromPreview() { showDetectionPreview = false; isProcessing = false }

    // MARK: - Internal State Reset
    func resetState(clearImage: Bool = true) {
        print("ViewModel: Resetting state.")
        if clearImage { self.selfieImage = nil }
        self.detectedObjects = [] // Use explicit type if needed [] as [DetectedObject]
        self.detectionErrorMessage = nil
        self.isProcessing = false
        self.showDetectionPreview = false
        self.showFrontCamera = false
    }

    // MARK: - Object Detection Logic

    private func performObjectDetection(on image: UIImage) async {
        // Set state on main actor (already here)
        self.isProcessing = true
        self.detectionErrorMessage = nil
        self.detectedObjects = []

        guard let cgImage = image.cgImage else {
            detectionErrorMessage = "Failed to load image."; isProcessing = false; return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("ProtectiveGearViewModel: Starting Object Detection...")

        var processingError: String? = nil // Local error accumulation

        do {
            // --- Load Model ---
            print("Loading yolo11x model...")
            // *** Replace 'yolo11x' if needed ***
            guard let coreMLModel = try? yolo11x(configuration: MLModelConfiguration()).model else {
                 throw NSError(domain: "ProtectiveGearViewModel", code: 100, userInfo: [NSLocalizedDescriptionKey: "Failed to load yolo11x model."])
            }
            let visionModel = try VNCoreMLModel(for: coreMLModel)
            print("yolo11x model loaded.")

            // --- Create Request ---
            let request = VNCoreMLRequest(model: visionModel) { [weak self] (request, error) in
                 // --- Completion Handler (Background Thread) ---
                 guard let self = self else { return }

                 var handlerDetections: [DetectedObject] = []
                 var handlerError: String? = nil

                 if let error = error {
                     print("Object Detection Error: \(error.localizedDescription)")
                     handlerError = "Detection request failed."
                 } else if let results = request.results {
                     print("Object Detection Raw Results Count: \(results.count)")
                     let outputName = "var_2219" // *** VERIFY ***

                     guard let observation = results.first as? VNCoreMLFeatureValueObservation,
                           let tensor = observation.featureValue.multiArrayValue else {
                           print("Parsing Error: Could not get MLMultiArray output tensor.")
                           handlerError = "Invalid model output format."
                           // Need to update state from here too
                           Task { @MainActor in self.updateDetectionState(detections: [], error: handlerError) }
                           return // Exit completion handler
                     }
                     print("DEBUG: Output Tensor '\(outputName)' Shape: \(tensor.shape)")

                     // --- Call External Parser ---
                     print("Calling YOLOv8Parser...")
                     let parseResult = self.objectParser.parse(tensor: tensor) // Use instance
                     handlerDetections = parseResult.detections
                     if let parseError = parseResult.error {
                          handlerError = parseError
                     }
                     print("Parsing complete. Found: \(handlerDetections.count)")

                 } else { handlerError = "No results from model." }

                 // --- Update State via Task @MainActor ---
                 Task { @MainActor in
                     self.updateDetectionState(detections: handlerDetections, error: handlerError)
                 }
                 // --- End State Update ---
            } // --- End Completion Handler ---


            // --- Perform Request ---
             print("Performing VNCoreMLRequest...")
             let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation, options: [:])
             try requestHandler.perform([request])
             print("VNCoreMLRequest perform call completed (results handled async).")

        } catch {
            print("Error setting up or performing object detection: \(error)")
            processingError = "Setup/Perform Error (\(error.localizedDescription.prefix(50)))"
            // Update state directly here on setup/perform error
            self.updateDetectionState(detections: [], error: processingError)
        }
        // Note: Final state update (isProcessing=false, showDetectionPreview=true)
        // now happens *within* the completion handler's MainActor Task via updateDetectionState
    } // End performObjectDetection


    /// Centralized function to update state after detection attempt
    private func updateDetectionState(detections: [DetectedObject], error: String?) {
        print("Updating state on main actor...")
        self.detectedObjects = detections
        self.detectionErrorMessage = error
        // Show preview if we got detections OR if an error occurred to show the message
        if !detections.isEmpty || error != nil {
             self.showDetectionPreview = true
             print("Triggering detection preview.")
             // Keep processing indicator ON until user acts on preview
             self.isProcessing = true // <<< KEEP TRUE until proceed/retake
        } else {
             // No detections and no error
             self.showDetectionPreview = false
             self.isProcessing = false // OK to stop processing
             print("No detections/error, not showing preview, stopping processing.")
        }
    }


    // MARK: - Orientation Helper
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
            @unknown default: return .up
         }
    }
} // End ViewModel
