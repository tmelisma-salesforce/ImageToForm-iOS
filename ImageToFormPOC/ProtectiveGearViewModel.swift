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
struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Expecting a standard CGRect
}
// --- End DetectedObject Definition ---


@MainActor
class ProtectiveGearViewModel: ObservableObject {

    // MARK: - Published State (UI Facing)
    @Published var selfieImage: UIImage? = nil
    @Published var isProcessing = false
    @Published var detectionErrorMessage: String? = nil
    @Published var showCamera = false
    @Published var showDetectionPreview = false

    // --- Checklist State ---
    @Published var isHelmetChecked: Bool = false
    @Published var isGlovesChecked: Bool = false
    @Published var isBootsChecked: Bool = false
    @Published var showFlipFlopErrorAlert: Bool = false

    // --- State for Preview ---
    @Published var objectsForPreview: [DetectedObject] = []
    @Published var previewMessage: String? = nil

    // MARK: - Internal State
    var isFrontCamera: Bool = false
    private(set) var lastScanWasFrontCamera: Bool = false

    // --- Temporary Findings (Internal) ---
    private var foundHelmetInLastScan = false
    private var foundGloveInLastScan = false
    private var foundBootsInLastScan = false
    private var foundFlipFlopsInLastScan = false

    // MARK: - Dependencies
    private var coreMLModel: MLModel?
    private var modelContainer: CoreMLModelContainer?

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

    // MARK: - Actions from UI

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

    // MARK: - Internal State Reset

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
        self.lastScanWasFrontCamera = false
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

        let visionOrientation = cgOrientation(from: image.imageOrientation)
        print("ProtectiveGearViewModel DEBUG: Original UIImage Orientation: \(image.imageOrientation.rawValue)")
        print("ProtectiveGearViewModel DEBUG: Passing orientation \(visionOrientation.rawValue) to Vision request.")

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
            print("ProtectiveGearViewModel DEBUG: Performing CoreMLRequest directly with orientation \(visionOrientation.rawValue)...")

            // Let Swift infer the type [any VisionObservation]
            let visionObservations = try await request.perform(on: cgImage, orientation: visionOrientation)

            print("ProtectiveGearViewModel DEBUG: CoreMLRequest perform completed. Received \(visionObservations.count) observations.")

            var detectedObjectsFromVision: [DetectedObject] = []
            for observation in visionObservations {
                guard let recognizedObjectObservation = observation as? RecognizedObjectObservation else {
                    print("ProtectiveGearViewModel DEBUG: Skipping observation of type \(type(of: observation)). Expected RecognizedObjectObservation.")
                    continue
                }

                guard let topLabel = recognizedObjectObservation.labels.max(by: { $0.confidence < $1.confidence }) else { continue }
                guard expectedLabels.contains(topLabel.identifier) else { continue }

                let combinedConfidence = recognizedObjectObservation.confidence * topLabel.confidence

                // --- CORRECTED: Construct CGRect from components ---
                // Access components directly from the boundingBox (NormalizedRect)
                let box = CGRect(
                    x: recognizedObjectObservation.boundingBox.origin.x,
                    y: recognizedObjectObservation.boundingBox.origin.y,
                    width: recognizedObjectObservation.boundingBox.width,
                    height: recognizedObjectObservation.boundingBox.height
                )
                // --- END CORRECTION ---

                // Initialize DetectedObject with the newly constructed CGRect
                let detectedObject = DetectedObject(
                    label: topLabel.identifier,
                    confidence: combinedConfidence,
                    boundingBox: box // Use the constructed CGRect
                )

                detectedObjectsFromVision.append(detectedObject)
                print("ProtectiveGearViewModel DEBUG: Added DetectedObject: \(detectedObject.label) (Conf: \(String(format: "%.2f", detectedObject.confidence))) Box: \(detectedObject.boundingBox)")
            }

            print("Processing complete. Found: \(detectedObjectsFromVision.count) relevant detections.")
            updateDetectionState(detections: detectedObjectsFromVision, error: nil)

        } catch {
            print("ProtectiveGearViewModel Error: Failed to perform CoreMLRequest: \(error.localizedDescription)")
            updateDetectionState(detections: [], error: "CoreMLRequest failed: \(error.localizedDescription)")
        }
    } // End performCoreMLRequest

    // MARK: - updateDetectionState
    private func updateDetectionState(detections: [DetectedObject], error: String?) {
        print("Updating state on main actor after detection...")
        self.detectionErrorMessage = error

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
        } else { // Rear camera
            relevantObjectsForPreview = detections.filter { $0.label == "boots" || $0.label == "flip-flops" }
            if foundFlipFlopsInLastScan {
                message = "Flip-flops detected. Not suitable protective gear."
            } else if !foundBootsInLastScan {
                message = "No boots detected."
            }
        }

        self.objectsForPreview = relevantObjectsForPreview
        self.previewMessage = message ?? self.detectionErrorMessage

        self.showDetectionPreview = true
        self.isProcessing = true

        print("Triggering detection preview (\(relevantObjectsForPreview.count) objects for preview, message: \(self.previewMessage ?? "None")).")
    }

    // MARK: - Orientation Helper
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up
            case .down: return .down
            case .left: return .left
            case .right: return .right
            case .upMirrored: return .upMirrored
            case .downMirrored: return .downMirrored
            case .leftMirrored: return .leftMirrored
            case .rightMirrored: return .rightMirrored
            @unknown default:
                print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up")
                return .up
         }
    }

} // End ViewModel

