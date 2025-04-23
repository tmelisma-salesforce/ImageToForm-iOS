//
//  YOLOv8Parser.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Vision // Keep Vision for CGRect etc. if needed by DetectedObject
import CoreML
import CoreGraphics
import Accelerate // Keep for NMS

// MARK: - Supporting Struct Definitions
// Ensure this struct is defined accessibly
struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized Rect (0-1), TOP-LEFT origin assumed
    let classIndex: Int
}

// Renamed for clarity with new parsing logic
private struct PotentialDetection {
    let index: Int // Original index from tensors
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized, top-left
    let classIndex: Int
}

// MARK: - Parser Logic for Fine-Tuned Model
struct YOLOv8Parser {

    // --- NEW Class Labels (MUST match your model's metadata) ---
    private let classLabels = [
        "flip-flops", "helmet", "glove", "boots" // Index 0, 1, 2, 3
    ]
    private var numClasses: Int { classLabels.count } // Will be 4

    // --- Configurable Thresholds ---
    private let confidenceThreshold: Float
    private let iouThreshold: Float // For Non-Maximum Suppression

    // --- Model Input Size ---
    // Assuming 640x640 based on user info
    private let modelInputSize = CGSize(width: 640, height: 640)

    init(confidenceThreshold: Float = 0.30, iouThreshold: Float = 0.45) {
        self.confidenceThreshold = confidenceThreshold
        self.iouThreshold = iouThreshold
        print("YOLOv8Parser (Fine-Tuned) initialized with Conf Threshold: \(self.confidenceThreshold), IoU Threshold: \(self.iouThreshold)")
        print("YOLOv8Parser (Fine-Tuned) expecting class labels: \(self.classLabels)")
    }

    // MARK: - Public Parsing Function

    public func parse(confidenceTensor: MLMultiArray, coordinatesTensor: MLMultiArray) -> (detections: [DetectedObject], error: String?) {
        print("YOLOv8Parser (Fine-Tuned): Starting tensor parsing...")

        // --- Basic Shape Validation ---
        guard confidenceTensor.shape.count == 2, let numDetectionsConf = confidenceTensor.shape[0] as? Int, let numClassesConf = confidenceTensor.shape[1] as? Int else {
            return ([], "Invalid confidence tensor shape: \(confidenceTensor.shape)")
        }
        guard coordinatesTensor.shape.count == 2, let numDetectionsCoord = coordinatesTensor.shape[0] as? Int, coordinatesTensor.shape[1] == 4 else {
             return ([], "Invalid coordinates tensor shape: \(coordinatesTensor.shape)")
        }
        guard numDetectionsConf == numDetectionsCoord else {
             return ([], "Mismatch in number of detections between confidence (\(numDetectionsConf)) and coordinates (\(numDetectionsCoord)) tensors.")
        }
        let numDetections = numDetectionsConf
        let actualNumClasses = numClassesConf

        print("YOLOv8Parser (Fine-Tuned) DEBUG: Validated Shapes. NumDetections=\(numDetections), NumClasses=\(actualNumClasses)")

        // --- Decode Candidates ---
        var candidates: [PotentialDetection] = []
        var maxConfidenceFound: Float = 0.0

        for i in 0..<numDetections {
            // --- Bounding Box Decoding ---
            let x = CGFloat(coordinatesTensor[[i as NSNumber, 0]].floatValue)
            let y = CGFloat(coordinatesTensor[[i as NSNumber, 1]].floatValue)
            let w = CGFloat(coordinatesTensor[[i as NSNumber, 2]].floatValue)
            let h = CGFloat(coordinatesTensor[[i as NSNumber, 3]].floatValue)

            let clampedX = max(0.0, x); let clampedY = max(0.0, y)
            let clampedW = min(w, 1.0 - clampedX); let clampedH = min(h, 1.0 - clampedY)

            guard clampedW > 0, clampedH > 0 else { continue }
            let finalRect = CGRect(x: clampedX, y: clampedY, width: clampedW, height: clampedH)

            // --- Confidence Calculation ---
            var bestClassIndex = -1
            var maxClassConfidence: Float = -Float.infinity

            for classIndex in 0..<actualNumClasses {
                let confidence = confidenceTensor[[i as NSNumber, classIndex as NSNumber]].floatValue
                if confidence > maxClassConfidence {
                    maxClassConfidence = confidence
                    bestClassIndex = classIndex
                }
            }

            if maxClassConfidence > maxConfidenceFound { maxConfidenceFound = maxClassConfidence }

            // Filter by CONFIDENCE threshold
            if maxClassConfidence >= self.confidenceThreshold && bestClassIndex != -1 {
                 guard bestClassIndex < self.classLabels.count else {
                     print("YOLOv8Parser (Fine-Tuned) Warning: bestClassIndex \(bestClassIndex) is out of bounds for configured labels array (\(self.classLabels.count) labels).")
                     continue
                 }
                 let label = self.classLabels[bestClassIndex]
                 candidates.append(PotentialDetection(
                     index: i,
                     label: label,
                     confidence: maxClassConfidence,
                     boundingBox: finalRect,
                     classIndex: bestClassIndex
                 ))
            }
        } // End loop

        print("YOLOv8Parser (Fine-Tuned) DEBUG: Max Confidence Found: \(String(format: "%.4f", maxConfidenceFound))")
        print("YOLOv8Parser (Fine-Tuned): Decoded \(candidates.count) candidates above threshold (\(self.confidenceThreshold)).")

        // Apply NMS
        let finalDetections = applyNMS(candidates: candidates, iouThreshold: self.iouThreshold)
        print("YOLOv8Parser (Fine-Tuned) NMS complete. Kept \(finalDetections.count) detections.")

        return (finalDetections, nil)
    }

    // MARK: - Private Helper Functions

    /// Performs Non-Maximum Suppression
    private func applyNMS(candidates: [PotentialDetection], iouThreshold: Float) -> [DetectedObject] {
        if candidates.isEmpty { return [] }

        let groupedCandidates = Dictionary(grouping: candidates, by: { $0.classIndex })
        var finalDetections: [DetectedObject] = []

        print("YOLOv8Parser (Fine-Tuned) NMS: Processing \(groupedCandidates.count) classes.")

        // Fixed warning: Replaced 'classIndex' with '_' as it wasn't used in the loop itself
        for (_, group) in groupedCandidates {
            var sortedGroup = group.sorted { $0.confidence > $1.confidence }
            while !sortedGroup.isEmpty {
                let bestCandidate = sortedGroup.removeFirst()
                finalDetections.append(DetectedObject(
                    label: bestCandidate.label,
                    confidence: bestCandidate.confidence,
                    boundingBox: bestCandidate.boundingBox,
                    classIndex: bestCandidate.classIndex // Use classIndex from bestCandidate
                ))
                sortedGroup.removeAll { calculateIoU(boxA: bestCandidate.boundingBox, boxB: $0.boundingBox) > iouThreshold }
            }
        }
        return finalDetections
    }


    /// Calculates Intersection over Union (IoU) - Unchanged
    private func calculateIoU(boxA: CGRect, boxB: CGRect) -> Float {
        guard boxA.width > 0, boxA.height > 0, boxB.width > 0, boxB.height > 0 else { return 0.0 }
        let intersectionX = max(boxA.minX, boxB.minX)
        let intersectionY = max(boxA.minY, boxB.minY)
        let intersectionMaxX = min(boxA.maxX, boxB.maxX)
        let intersectionMaxY = min(boxA.maxY, boxB.maxY)
        let intersectionWidth = max(0, intersectionMaxX - intersectionX)
        let intersectionHeight = max(0, intersectionMaxY - intersectionY)
        let intersectionArea = intersectionWidth * intersectionHeight
        if intersectionArea <= 0 { return 0.0 }
        let boxAArea = boxA.width * boxA.height
        let boxBArea = boxB.width * boxB.height
        let unionArea = boxAArea + boxBArea - intersectionArea
        if unionArea <= 0 { return 0.0 }
        let iou = intersectionArea / unionArea
        return max(0.0, min(Float(iou), 1.0))
    }

} // End YOLOv8Parser struct
