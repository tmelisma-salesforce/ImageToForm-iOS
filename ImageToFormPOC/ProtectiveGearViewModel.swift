//
//  ProtectiveGearViewModel.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision       // Use new Swift Vision API
import CoreML
import CoreGraphics

// Note: Requires iOS 18.0+ / macOS 15.0+ for CoreMLRequest, CoreMLModelContainer etc.
// Also requires iOS 15.0+ / macOS 12.0+ for MLShapedArray

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
    private let objectParser = YOLOv8Parser()
    private var coreMLModel: MLModel?
    private var modelContainer: CoreMLModelContainer?

    // MARK: - Initialization
    init() {
        loadModelAndContainer()
    }

    // MARK: - Model Loading and Container Creation
    private func loadModelAndContainer() {
        guard let modelURL = Bundle.main.url(forResource: "best", withExtension: "mlmodelc") else {
             print("ProtectiveGearViewModel Error: Failed to find best.mlmodelc in bundle.")
             self.detectionErrorMessage = "ML Model file not found."
             return
        }
        print("ProtectiveGearViewModel DEBUG: Found model file at URL: \(modelURL.path)")
        do {
             self.coreMLModel = try MLModel(contentsOf: modelURL)
             print("ProtectiveGearViewModel DEBUG: MLModel loaded successfully.")
             self.modelContainer = try CoreMLModelContainer(model: self.coreMLModel!)
             print("ProtectiveGearViewModel DEBUG: CoreMLModelContainer created successfully.")
             if let modelDesc = self.coreMLModel?.modelDescription {
                 print("ProtectiveGearViewModel DEBUG: Model Description Loaded.")
                 print("  Input Features: \(modelDesc.inputDescriptionsByName)")
                 print("  Output Features: \(modelDesc.outputDescriptionsByName)")
             } else {
                 print("ProtectiveGearViewModel WARNING: Could not get model description.")
             }
             print("ProtectiveGearViewModel: Successfully loaded model and created container.")
        } catch {
             print("ProtectiveGearViewModel Error: Failed to load MLModel or create CoreMLModelContainer: \(error)")
             self.coreMLModel = nil; self.modelContainer = nil
             self.detectionErrorMessage = "Failed to load ML Model/Container (\(error.localizedDescription))."
        }
    }

    // MARK: - Actions from UI
    func checkGearButtonTapped() { resetState(); showFrontCamera = true }

    func imageCaptured(_ image: UIImage?) {
        guard let capturedImage = image else {
             print("ProtectiveGearViewModel Warning: imageCaptured called with nil image.")
             return
         }
        self.selfieImage = capturedImage
        Task {
            await performCoreMLRequest(capturedImage)
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

    // MARK: - Object Detection Logic (NEW Swift-only Vision API - iOS 18+)

    private func performCoreMLRequest(_ image: UIImage) async {
        guard let loadedModelContainer = self.modelContainer else {
             updateDetectionState(detections: [], error: "ML Model Container not loaded.")
             return
        }
        guard let cgImage = image.cgImage else {
            updateDetectionState(detections: [], error: "Failed to convert image.")
            return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)

        print("ProtectiveGearViewModel: Starting Object Detection Task (NEW Swift Vision API)...")
        self.isProcessing = true
        self.detectionErrorMessage = nil
        self.detectedObjects = []

        do {
            let request = CoreMLRequest(model: loadedModelContainer)
            print("ProtectiveGearViewModel DEBUG: Performing CoreMLRequest directly...")
            let visionObservations = try await request.perform(on: cgImage, orientation: imageOrientation)
            print("ProtectiveGearViewModel DEBUG: CoreMLRequest perform completed. Received \(visionObservations.count) observations.")

            var confidenceMultiArray: MLMultiArray?
            var coordinatesMultiArray: MLMultiArray?

            for observation in visionObservations {
                guard let coreMLObservation = observation as? CoreMLFeatureValueObservation else {
                    print("ProtectiveGearViewModel DEBUG: Skipping observation of type \(type(of: observation)). Expected CoreMLFeatureValueObservation.")
                    continue
                }
                print("ProtectiveGearViewModel DEBUG: Processing CoreMLFeatureValueObservation with featureName: \(coreMLObservation.featureName)")

                // Extract MLShapedArray from MLSendableFeatureValue
                guard let shapedArray = coreMLObservation.featureValue.shapedArrayValue(of: Float.self) else {
                    print("ProtectiveGearViewModel WARNING: Observation \(coreMLObservation.featureName) featureValue doesn't contain MLShapedArray<Float>.")
                    continue
                }

                // --- CORRECTED: Convert MLShapedArray -> MLMultiArray Directly ---
                // Use the initializer documented for MLMultiArray
                let multiArray = MLMultiArray(shapedArray)
                // Note: This initializer might still fail if types/shapes mismatch underlying expectations,
                // but it's the documented way. Error handling might be needed if it can fail.
                // --- End Direct Conversion ---

                // Assign based on feature name
                if coreMLObservation.featureName == "confidence" {
                    confidenceMultiArray = multiArray
                    print("  -> Found and converted 'confidence' tensor. Shape: \(multiArray.shape)")
                } else if coreMLObservation.featureName == "coordinates" {
                    coordinatesMultiArray = multiArray
                    print("  -> Found and converted 'coordinates' tensor. Shape: \(multiArray.shape)")
                }
            }

            // Verify Tensors
            guard let confTensor = confidenceMultiArray, let coordTensor = coordinatesMultiArray else {
                 print("ProtectiveGearViewModel Error: Failed to find or convert both 'confidence' and 'coordinates' tensors from results.")
                 if !visionObservations.contains(where: { $0 is CoreMLFeatureValueObservation }) {
                      print("  Reason: No CoreMLFeatureValueObservation objects found in results.")
                 }
                 updateDetectionState(detections: [], error: "Model output format error (missing/invalid tensors).")
                 return
            }

            // Call Parser
            print("Calling YOLOv8Parser (Fine-Tuned)...")
            let parseResult = self.objectParser.parse(
                confidenceTensor: confTensor,
                coordinatesTensor: coordTensor
            )
            print("Parsing complete. Found: \(parseResult.detections.count) final detections.")

            // Update State
            updateDetectionState(detections: parseResult.detections, error: parseResult.error)

        } catch {
            print("ProtectiveGearViewModel Error: Failed to perform CoreMLRequest: \(error.localizedDescription)")
            updateDetectionState(detections: [], error: "CoreMLRequest failed: \(error.localizedDescription)")
        }
    } // End performCoreMLRequest

    /// Centralized function to update state after detection attempt
    private func updateDetectionState(detections: [DetectedObject], error: String?) {
        print("Updating state on main actor...")
        self.detectedObjects = detections
        self.detectionErrorMessage = error
        if !detections.isEmpty || error != nil {
             self.showDetectionPreview = true
             print("Triggering detection preview (\(detections.count) detections, error: \(error != nil)).")
             self.isProcessing = true
        } else {
             self.showDetectionPreview = false
             self.isProcessing = false
             print("No detections and no error, not showing preview, stopping processing.")
        }
        if !self.showDetectionPreview {
            self.isProcessing = false
        }
    }

    // MARK: - Orientation Helper
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
            @unknown default: print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up"); return .up
         }
    }

} // End ViewModel

// REMOVED: MLShapedArray to MLMultiArray Conversion Helper extension is no longer needed
