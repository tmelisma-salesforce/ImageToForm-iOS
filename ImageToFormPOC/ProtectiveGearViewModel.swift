//
//  ProtectiveGearViewModel.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision        // Vision framework
import CoreML        // CoreML for model loading
import CoreGraphics  // For orientation, CGRect
import Accelerate    // For potential NMS optimizations later

// Ensure Deployment Target is iOS 18.0+ or compatible

// Supporting Structs should be defined elsewhere (e.g., YOLOv8Parser.swift or Models.swift)
// Ensure DetectedObject is Identifiable where it's defined.

@MainActor
class ProtectiveGearViewModel: ObservableObject {

    // MARK: - Published State
    @Published var selfieImage: UIImage? = nil
    @Published var isProcessing = false
    @Published var detectedObjects: [DetectedObject] = []
    @Published var detectionErrorMessage: String? = nil
    @Published var showDetectionPreview = false
    @Published var showFrontCamera = false

    // MARK: - Dependencies
    // Assumes YOLOv8Parser.swift contains the YOLOv8Parser struct definition
    private let objectParser = YOLOv8Parser()

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
        print("ViewModel: Resetting state (clearImage: \(clearImage)).")
        if clearImage { self.selfieImage = nil }
        self.detectedObjects = []
        self.detectionErrorMessage = nil
        self.isProcessing = false
        self.showDetectionPreview = false
        self.showFrontCamera = false
    }

    // MARK: - Object Detection Logic

    private func performObjectDetection(on image: UIImage) async {
        self.isProcessing = true
        self.detectionErrorMessage = nil
        self.detectedObjects = []

        guard let cgImage = image.cgImage else {
            await MainActor.run {
                self.detectionErrorMessage = "Failed to convert image for processing."
                self.isProcessing = false
            }
            return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("ProtectiveGearViewModel: Starting Object Detection...")

        var processingError: String? = nil

        do {
            // --- 1. Load Model ---
            print("Loading yolov8l model...")
            guard let coreMLModel = try? yolov8l(configuration: MLModelConfiguration()).model else {
                 throw NSError(domain: "ProtectiveGearViewModel", code: 100, userInfo: [NSLocalizedDescriptionKey: "Failed to load yolov8l model."])
            }
            let visionModel = try VNCoreMLModel(for: coreMLModel)
            print("yolov8l model loaded.")

            // --- 2. Create Request with Completion Handler ---
            let request = VNCoreMLRequest(model: visionModel) { [weak self] (request, error) in
                 // --- 3. Process Results (Completion Handler - Background Thread) ---
                 guard let self = self else { return }

                 var handlerDetections: [DetectedObject] = []
                 var handlerError: String? = nil

                 if let error = error {
                     print("Object Detection Completion Error: \(error.localizedDescription)")
                     handlerError = "Detection request failed."
                 } else if let results = request.results {
                     print("Object Detection Raw Results Count: \(results.count)")

                     // --- CORRECTED TENSOR ACCESS ---
                     // Access primary multi-array output directly from featureValue
                     guard let observation = results.first as? VNCoreMLFeatureValueObservation,
                           let tensor = observation.featureValue.multiArrayValue else {
                           print("Parsing Error: Could not get MLMultiArray output tensor from featureValue.")
                           handlerError = "Invalid model output format."
                           // Update state via Task below
                           Task { @MainActor in self.updateDetectionState(detections: [], error: handlerError) }
                           return // Exit completion handler early
                     }
                     // --- END CORRECTION ---

                     print("DEBUG: Output Tensor Shape: \(tensor.shape)") // Tensor is non-optional here

                     // --- 4. Call External Parser ---
                     print("Calling YOLOv8Parser...")
                     let parseResult = self.objectParser.parse(tensor: tensor) // Use the parser instance
                     handlerDetections = parseResult.detections
                     if let parseError = parseResult.error { handlerError = parseError }
                     print("Parsing complete. Found: \(handlerDetections.count)")

                 } else { handlerError = "No results from model." }

                 // --- 5. UPDATE STATE ON MAIN ACTOR ---
                 Task { @MainActor in
                     self.updateDetectionState(detections: handlerDetections, error: handlerError)
                 }
                 // --- END STATE UPDATE ---

            } // --- End VNCoreMLRequest completion handler ---


            // --- Configure Request (Corrected Enum Usage) ---
            // Use the explicit enum name for clarity and to avoid inference issues
            request.imageCropAndScaleOption = VNImageCropAndScaleOption.scaleFit
            print("DEBUG: Set imageCropAndScaleOption to .scaleFit")
            // --- End Configuration ---

            // --- Perform Request ---
             print("Performing VNCoreMLRequest...")
             let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: imageOrientation, options: [:])
             try requestHandler.perform([request])
             print("VNCoreMLRequest perform call completed (results handled async).")

        } catch { // Handle setup/perform errors
            print("Error setting up or performing object detection: \(error)")
            processingError = "Setup/Perform Error (\(error.localizedDescription.prefix(50)))"
            // Update state directly for these critical errors
            self.updateDetectionState(detections: [], error: processingError)
        }
    } // End performObjectDetection


    /// Centralized function to update state after detection attempt (runs on MainActor)
    private func updateDetectionState(detections: [DetectedObject], error: String?) {
        print("Updating state on main actor...")
        self.detectedObjects = detections
        self.detectionErrorMessage = error
        if !detections.isEmpty || error != nil {
             self.showDetectionPreview = true
             print("Triggering detection preview.")
             // Keep isProcessing = true until user acts on preview
             self.isProcessing = true // Keep indicator showing while preview is up
        } else {
             self.showDetectionPreview = false
             self.isProcessing = false // Stop processing if nothing to show/review
             print("No detections/error, not showing preview, stopping processing.")
        }
        // Logic refinement: Ensure isProcessing eventually becomes false
        // It's set false now in proceedFromPreview() and retakePhoto() which dismiss the preview.
        // Also need to handle case where preview isn't shown.
        if !self.showDetectionPreview {
            self.isProcessing = false
        }
    }

    // MARK: - Orientation Helper
    /// Converts UIImage.Orientation to CGImagePropertyOrientation. Marked private.
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
            @unknown default: return .up
         }
    }
} // End ViewModel
