//
//  ProtectiveGearViewModel.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Required for Vision types like RecognizedObjectObservation, ClassificationObservation, CoreMLRequest etc.
import CoreML // Required for MLModel
import CoreGraphics

// Note: Requires iOS 18.0+ / macOS 15.0+ for CoreMLRequest, CoreMLModelContainer etc.

// --- Define DetectedObject Struct Here (Single Source of Truth) ---
// This struct is populated directly from Vision observations.
struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String        // e.g., "helmet", "glove"
    let confidence: Float    // Combined confidence
    let boundingBox: CGRect // Normalized Rect (0-1), TOP-LEFT origin from Vision observation
}
// --- End DetectedObject Definition ---


@MainActor
class ProtectiveGearViewModel: ObservableObject {

    // MARK: - Published State (UI Facing)
    @Published var selfieImage: UIImage? = nil
    @Published var isProcessing = false
    @Published var detectionErrorMessage: String? = nil // For technical errors
    @Published var showCamera = false // Controls ImagePicker presentation
    @Published var showDetectionPreview = false // Controls ObjectDetectionPreviewView presentation

    // --- Checklist State ---
    @Published var isHelmetChecked: Bool = false
    @Published var isGlovesChecked: Bool = false
    @Published var isBootsChecked: Bool = false
    @Published var showFlipFlopErrorAlert: Bool = false // Controls the alert in the main view

    // --- State for Preview ---
    // Uses the DetectedObject struct defined above
    @Published var objectsForPreview: [DetectedObject] = [] // Filtered objects for the current preview
    @Published var previewMessage: String? = nil // Message to show in the preview (e.g., "No gear detected")

    // MARK: - Internal State
    var isFrontCamera: Bool = false // Track which camera was requested for the scan (Made internal, not private)
    private var lastScanWasFrontCamera: Bool = false // Track which camera was used for the *completed* scan

    // --- Temporary Findings (Internal) ---
    private var foundHelmetInLastScan = false
    private var foundGloveInLastScan = false
    private var foundBootsInLastScan = false
    private var foundFlipFlopsInLastScan = false

    // MARK: - Dependencies
    // REMOVED: Parser is no longer needed as we process Vision results directly
    private var coreMLModel: MLModel?
    private var modelContainer: CoreMLModelContainer?

    // Define expected class labels (ensure these match model output identifiers)
    private let expectedLabels: Set<String> = ["flip-flops", "helmet", "glove", "boots"]

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

    // MARK: - Actions from UI (No changes needed in this section)

    func initiateScan(useFrontCamera: Bool) {
        print("ViewModel: Initiating scan (useFrontCamera: \(useFrontCamera))")
        resetStateBeforeScan()
        self.isFrontCamera = useFrontCamera
        self.showCamera = true
    }

    func imageCaptured(_ image: UIImage?) {
        guard let capturedImage = image else {
             print("ProtectiveGearViewModel Warning: imageCaptured called with nil image.")
             isProcessing = false
             return
         }
        print("ViewModel: Image captured. Storing and starting detection task.")
        self.selfieImage = capturedImage
        self.lastScanWasFrontCamera = self.isFrontCamera
        Task {
            await performCoreMLRequest(capturedImage)
        }
    }

    func retakePhoto() {
        print("ViewModel: Retake requested.")
        resetStateBeforeScan()
        showDetectionPreview = false
        showCamera = true
    }

    func proceedFromPreview() {
        print("ViewModel: Proceeding from preview.")
        if lastScanWasFrontCamera {
            if foundHelmetInLastScan || foundGloveInLastScan {
                print("ViewModel: Setting Helmet and Gloves checked.")
                isHelmetChecked = true
                isGlovesChecked = true
            }
        } else {
            if foundFlipFlopsInLastScan {
                print("ViewModel: Flip-flops detected, triggering alert.")
                showFlipFlopErrorAlert = true
            } else if foundBootsInLastScan {
                print("ViewModel: Setting Boots checked.")
                isBootsChecked = true
            }
        }
        showDetectionPreview = false
        isProcessing = false
        print("ViewModel: Proceed complete. Checklist state updated.")
    }

    // MARK: - Internal State Reset (No changes needed in this section)

    private func resetStateBeforeScan() {
        print("ViewModel: Resetting state before new scan.")
        self.selfieImage = nil
        self.objectsForPreview = []
        self.previewMessage = nil
        self.detectionErrorMessage = nil
        self.isProcessing = false
        self.showDetectionPreview = false
        self.showCamera = false
        self.foundHelmetInLastScan = false
        self.foundGloveInLastScan = false
        self.foundBootsInLastScan = false
        self.foundFlipFlopsInLastScan = false
    }

    func resetAllState() {
        print("ViewModel: Resetting ALL state.")
        resetStateBeforeScan()
        self.isHelmetChecked = false
        self.isGlovesChecked = false
        self.isBootsChecked = false
        self.showFlipFlopErrorAlert = false
    }


    // MARK: - Object Detection Logic (Using CoreMLRequest - iOS 18+)

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

        print("ProtectiveGearViewModel: Starting Object Detection Task (CoreMLRequest)...")
        self.isProcessing = true
        self.detectionErrorMessage = nil
        self.objectsForPreview = []
        self.previewMessage = nil
        self.foundHelmetInLastScan = false
        self.foundGloveInLastScan = false
        self.foundBootsInLastScan = false
        self.foundFlipFlopsInLastScan = false

        do {
            let request = CoreMLRequest(model: loadedModelContainer)
            print("ProtectiveGearViewModel DEBUG: Performing CoreMLRequest directly...")

            // Let Swift infer the type as CoreMLRequest.Result (aka [any VisionObservation])
            let visionObservations = try await request.perform(on: cgImage, orientation: imageOrientation)

            print("ProtectiveGearViewModel DEBUG: CoreMLRequest perform completed. Received \(visionObservations.count) observations.")

            var detectedObjectsFromVision: [DetectedObject] = []
            // Loop iterates through the inferred [any VisionObservation] array
            for observation in visionObservations {
                // Use conditional cast (as?) to check if the element is the expected type
                guard let recognizedObjectObservation = observation as? RecognizedObjectObservation else {
                    print("ProtectiveGearViewModel DEBUG: Skipping observation of type \(type(of: observation)). Expected RecognizedObjectObservation.")
                    continue
                }

                // Now we know it's a RecognizedObjectObservation
                guard let topLabel = recognizedObjectObservation.labels.max(by: { $0.confidence < $1.confidence }) else {
                    print("ProtectiveGearViewModel DEBUG: Observation \(recognizedObjectObservation.uuid) has no labels. Skipping.")
                    continue
                }

                guard expectedLabels.contains(topLabel.identifier) else {
                     print("ProtectiveGearViewModel DEBUG: Top label '\(topLabel.identifier)' (Conf: \(topLabel.confidence)) is not in expectedLabels. Skipping.")
                     continue
                }

                let combinedConfidence = recognizedObjectObservation.confidence * topLabel.confidence

                // --- CORRECTED: Access the .cgRect property of the NormalizedRect ---
                let box = recognizedObjectObservation.boundingBox.cgRect // Get the underlying CGRect
                // --- END CORRECTION ---

                // --- Use the extracted CGRect in the initializer ---
                let detectedObject = DetectedObject(
                    label: topLabel.identifier,
                    confidence: combinedConfidence,
                    boundingBox: box // Use the extracted CGRect
                )
                // --- END CHANGE ---

                detectedObjectsFromVision.append(detectedObject)
                print("ProtectiveGearViewModel DEBUG: Added DetectedObject: \(detectedObject.label) (Conf: \(String(format: "%.2f", detectedObject.confidence))) Box: \(detectedObject.boundingBox)")
            }

            print("Processing complete. Found: \(detectedObjectsFromVision.count) relevant detections.")
            // Pass nil error explicitly if successful
            updateDetectionState(detections: detectedObjectsFromVision, error: nil)

        } catch {
            print("ProtectiveGearViewModel Error: Failed to perform CoreMLRequest: \(error.localizedDescription)")
            updateDetectionState(detections: [], error: "CoreMLRequest failed: \(error.localizedDescription)")
        }
    } // End performCoreMLRequest

    // MARK: - updateDetectionState (No changes needed here)
    private func updateDetectionState(detections: [DetectedObject], error: String?) {
        print("Updating state on main actor after detection...")
        self.detectionErrorMessage = error // Store any technical error

        var relevantObjectsForPreview: [DetectedObject] = []
        var message: String? = nil

        for detection in detections {
            switch detection.label {
            case "helmet": foundHelmetInLastScan = true
            case "glove": foundGloveInLastScan = true
            case "boots": foundBootsInLastScan = true
            case "flip-flops": foundFlipFlopsInLastScan = true
            default: break
            }
        }

        if lastScanWasFrontCamera {
            relevantObjectsForPreview = detections.filter { $0.label == "helmet" || $0.label == "glove" }
            if !foundHelmetInLastScan && !foundGloveInLastScan {
                message = "No helmet or gloves detected."
            }
        } else {
            relevantObjectsForPreview = detections.filter { $0.label == "boots" || $0.label == "flip-flops" }
            if foundFlipFlopsInLastScan {
                message = "Flip-flops detected. Not suitable protective gear."
            } else if !foundBootsInLastScan {
                message = "No boots detected."
            }
        }

        self.objectsForPreview = relevantObjectsForPreview
        // Show the generated message, or the technical error if one occurred
        self.previewMessage = message ?? self.detectionErrorMessage

        self.showDetectionPreview = true
        self.isProcessing = true

        print("Triggering detection preview (\(relevantObjectsForPreview.count) objects for preview, message: \(self.previewMessage ?? "None")).")
    }

    // MARK: - Orientation Helper (No changes needed here)
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
            @unknown default: print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up"); return .up
         }
    }

} // End ViewModel

