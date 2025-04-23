//
//  YOLOv8Parser.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

// Imports might not be needed if parse function remains inactive
import CoreML
import CoreGraphics

// MARK: - Supporting Struct Definitions

// --- REMOVED DetectedObject struct definition ---
// The single source of truth is now in ProtectiveGearViewModel.swift

// --- REMOVED PotentialDetection struct definition ---
// Not used by the current ViewModel logic.

// MARK: - Parser Logic (Currently Inactive)
struct YOLOv8Parser {

    // Class labels and thresholds might still be relevant if parsing logic is restored
    private let classLabels = [
        "flip-flops", "helmet", "glove", "boots"
    ]
    private var numClasses: Int { classLabels.count }

    private let confidenceThreshold: Float
    private let iouThreshold: Float

    private let modelInputSize = CGSize(width: 640, height: 640)

    init(confidenceThreshold: Float = 0.30, iouThreshold: Float = 0.45) {
        self.confidenceThreshold = confidenceThreshold
        self.iouThreshold = iouThreshold
        // Initial print statements are fine
        print("YOLOv8Parser initialized with Conf Threshold: \(self.confidenceThreshold), IoU Threshold: \(self.iouThreshold)")
        print("YOLOv8Parser expecting class labels: \(self.classLabels)")
    }

    // MARK: - Public Parsing Function (Keep Bypassed for now)

    // This function is NOT called by the current ViewModel logic.
    // It remains here in case direct tensor parsing is needed again later.
    // NOTE: If reactivated, the return type 'DetectedObject' must match the definition
    //       in ProtectiveGearViewModel.swift.
    public func parse(confidenceTensor: MLMultiArray, coordinatesTensor: MLMultiArray) -> (detections: [DetectedObject], error: String?) {
        print("YOLOv8Parser: NOTE - Parse function called, but logic is currently bypassed in ViewModel.")
        // Immediately return empty results
        return ([], "Parser logic inactive in ViewModel")

        /* // --- Original parsing logic remains commented out ---
        print("YOLOv8Parser (Fine-Tuned): Starting tensor parsing...")
        // ... (rest of the original parsing logic) ...
        // IMPORTANT: If uncommenting, ensure DetectedObject initialization matches the definition
        // in ProtectiveGearViewModel (i.e., no classIndex).
        return (finalDetections, nil)
        */
    }

    // MARK: - Private Helper Functions (Keep Commented Out)
    /*
    // NOTE: If reactivating NMS, ensure the types 'PotentialDetection' and 'DetectedObject'
    //       match the necessary definitions.
    private func applyNMS(candidates: [PotentialDetection], iouThreshold: Float) -> [DetectedObject] {
        // ... (NMS logic) ...
    }

    private func calculateIoU(boxA: CGRect, boxB: CGRect) -> Float {
        // ... (IoU logic) ...
    }
    */

} // End YOLOv8Parser struct

