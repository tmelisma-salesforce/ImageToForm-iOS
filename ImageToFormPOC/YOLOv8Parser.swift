//
//  YOLOv8Parser.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import Vision
import CoreML
import CoreGraphics
import Accelerate // Useful for optimized NMS if needed later

// MARK: - Supporting Structs (Defined here or globally)

// Represents a final detected object after parsing and NMS
struct DetectedObject: Identifiable {
    let id = UUID() // Conforms to Identifiable
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized Rect (0-1), TOP-LEFT origin
    let classIndex: Int
}

// Temporary struct used during NMS processing
private struct DetectionCandidate {
    let index: Int
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized, top-left
    let classIndex: Int
}

// MARK: - Parser Logic

struct YOLOv8Parser {

    // --- COCO Class Labels (80 Classes) ---
    // Ensure this list exactly matches the classes your specific yolo11x model was trained on.
    private let classLabels = [
        "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat",
        "traffic light", "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog",
        "horse", "sheep", "cow", "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella",
        "handbag", "tie", "suitcase", "frisbee", "skis", "snowboard", "sports ball", "kite",
        "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle",
        "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich",
        "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
        "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote",
        "keyboard", "cell phone", "microwave", "oven", "toaster", "sink", "refrigerator", "book",
        "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
    ]
    private var numClasses: Int { classLabels.count }

    // --- Configurable Thresholds ---
    private let confidenceThreshold: Float
    private let iouThreshold: Float

    init(confidenceThreshold: Float = 0.25, iouThreshold: Float = 0.45) {
        self.confidenceThreshold = confidenceThreshold
        self.iouThreshold = iouThreshold
    }

    /// Main function to parse the YOLOv8 output tensor.
    /// - Parameter tensor: The MLMultiArray output (Shape: [1, 84, 8400]).
    /// - Returns: Tuple containing final detections and optional error string.
    public func parse(tensor: MLMultiArray) -> (detections: [DetectedObject], error: String?) {
        print("YOLOv8Parser: Starting tensor parsing...")

        // --- Shape Validation ---
        guard tensor.shape.count == 3,
              let batch = tensor.shape[0] as? Int, batch == 1,
              let numOutputs = tensor.shape[1] as? Int, numOutputs == (numClasses + 4),
              let numDetections = tensor.shape.last?.intValue,
              numDetections > 0 else {
            print("YOLOv8Parser Error: Unexpected tensor shape: \(tensor.shape)")
            return ([], "Invalid tensor shape")
        }
        print("YOLOv8Parser DEBUG: Tensor Shape Valid: Batch=\(batch), Outputs=\(numOutputs), Detections=\(numDetections)")

        // --- Get Data Pointer ---
        guard let pointer = try? UnsafeMutableBufferPointer<Float32>(tensor) else {
             print("YOLOv8Parser Error: Failed to get buffer pointer.")
             return ([], "Tensor data access error")
        }

        // --- Decode Candidates ---
        var candidates: [DetectionCandidate] = []
        for i in 0..<numDetections {
            let baseIndex = i * numOutputs // Stride is number of outputs per detection
            guard baseIndex + 4 + numClasses <= pointer.count else { continue } // Bounds check

            // Box coordinates (cx, cy, w, h)
            let cx = CGFloat(pointer[baseIndex + 0])
            let cy = CGFloat(pointer[baseIndex + 1])
            let w = CGFloat(pointer[baseIndex + 2])
            let h = CGFloat(pointer[baseIndex + 3])
            let x = cx - w / 2.0
            let y = cy - h / 2.0

            guard x >= 0, y >= 0, w > 0, h > 0, x + w <= 1.0, y + h <= 1.0 else { continue }
            let rect = CGRect(x: x, y: y, width: w, height: h)

            // Find best class score/index (indices 4 to 4+numClasses-1)
            var bestClassIndex = -1
            var maxClassScore: Float = 0.0
            for classIndex in 0..<numClasses {
                let score = pointer[baseIndex + 4 + classIndex]
                if score > maxClassScore { maxClassScore = score; bestClassIndex = classIndex }
            }

            let confidence = maxClassScore // Use class score directly

            // Filter by confidence threshold
            if confidence >= confidenceThreshold && bestClassIndex != -1 {
                if bestClassIndex < classLabels.count {
                    let label = classLabels[bestClassIndex]
                    // Create candidate with all necessary info
                    candidates.append(DetectionCandidate(
                        index: i,
                        label: label,
                        confidence: confidence,
                        boundingBox: rect, // Normalized, Top-Left XYWH format
                        classIndex: bestClassIndex
                    ))
                } else {
                    print("YOLOv8Parser Warning: bestClassIndex \(bestClassIndex) out of bounds for classLabels.")
                }
            }
        } // End loop through detections
        print("YOLOv8Parser: Decoded \(candidates.count) candidates above threshold.")

        // --- Apply Non-Maximum Suppression ---
        let finalDetections = applyNMS(candidates: candidates, iouThreshold: iouThreshold)

        return (finalDetections, nil) // Return final detections and no error
    }

    // MARK: - NMS Implementation

    /// Performs Non-Maximum Suppression to filter overlapping bounding boxes.
    private func applyNMS(candidates: [DetectionCandidate], iouThreshold: Float) -> [DetectedObject] {
        if candidates.isEmpty { return [] }
        let groupedCandidates = Dictionary(grouping: candidates, by: { $0.classIndex })
        var finalDetections: [DetectedObject] = []

        for (_, group) in groupedCandidates {
            var sortedGroup = group.sorted { $0.confidence > $1.confidence }
            while !sortedGroup.isEmpty {
                let bestCandidate = sortedGroup.removeFirst()
                finalDetections.append(DetectedObject(
                    label: bestCandidate.label,
                    confidence: bestCandidate.confidence,
                    boundingBox: bestCandidate.boundingBox,
                    classIndex: bestCandidate.classIndex
                ))
                // Remove lower confidence boxes overlapping significantly
                sortedGroup.removeAll { calculateIoU(boxA: bestCandidate.boundingBox, boxB: $0.boundingBox) > iouThreshold }
            }
        }
        print("YOLOv8Parser NMS complete. Kept \(finalDetections.count) detections.")
        return finalDetections
    }

    /// Calculates Intersection over Union (IoU) for two rectangles.
    private func calculateIoU(boxA: CGRect, boxB: CGRect) -> Float {
        guard boxA.width > 0, boxA.height > 0, boxB.width > 0, boxB.height > 0 else { return 0.0 }
        let intersectionX = max(boxA.minX, boxB.minX)
        let intersectionY = max(boxA.minY, boxB.minY)
        let intersectionWidth = min(boxA.maxX, boxB.maxX) - intersectionX
        let intersectionHeight = min(boxA.maxY, boxB.maxY) - intersectionY
        if intersectionWidth <= 0 || intersectionHeight <= 0 { return 0.0 }
        let intersectionArea = intersectionWidth * intersectionHeight
        let areaA = boxA.width * boxA.height; let areaB = boxB.width * boxB.height
        let unionArea = areaA + areaB - intersectionArea
        if unionArea <= 0 { return 0.0 }
        let iou = intersectionArea / unionArea
        return max(0.0, min(Float(iou), 1.0))
    }
}
