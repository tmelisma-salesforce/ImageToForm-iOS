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
import Accelerate

// MARK: - Supporting Struct Definitions
struct DetectedObject: Identifiable {
    let id = UUID()
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized Rect (0-1), TOP-LEFT origin
    let classIndex: Int
}

private struct DetectionCandidate {
    let index: Int
    let label: String
    let confidence: Float
    let boundingBox: CGRect // Normalized, top-left
    let classIndex: Int
}

// MARK: - Parser Logic
struct YOLOv8Parser {

    // --- Class Labels ---
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

    // --- Model Input Size ---
    private let modelInputSize = CGSize(width: 640, height: 640) // *** VERIFY ***

    init(confidenceThreshold: Float = 0.25, iouThreshold: Float = 0.45) {
        self.confidenceThreshold = confidenceThreshold
        self.iouThreshold = iouThreshold
        print("YOLOv8Parser initialized with Confidence Threshold: \(self.confidenceThreshold), IoU Threshold: \(self.iouThreshold)")
    }

    // MARK: - Public Parsing Function

    public func parse(tensor: MLMultiArray) -> (detections: [DetectedObject], error: String?) {
        print("YOLOv8Parser: Starting tensor parsing...")
        // --- Shape Validation ---
        guard tensor.shape.count == 3,
              let batch = tensor.shape[0] as? Int, batch == 1,
              let numOutputs = tensor.shape[1] as? Int, numOutputs == (numClasses + 4),
              let numDetections = tensor.shape.last?.intValue, numDetections > 0 else {
            print("YOLOv8Parser Error: Unexpected tensor shape: \(tensor.shape)")
            return ([], "Invalid tensor shape")
        }
        print("YOLOv8Parser DEBUG: Tensor Shape Valid: Outputs=\(numOutputs), Detections=\(numDetections)")

        // --- Convert Tensor to [Float] ---
        // This simplifies the main processing loop by handling type conversion upfront.
        var floatData: [Float] = []
        do {
            floatData = try convertMultiArrayToFloatArray(tensor)
        } catch {
            return ([], "Tensor data conversion error: \(error)")
        }
        guard !floatData.isEmpty else {
            return ([], "Converted tensor data is empty")
        }

        // --- Decode Candidates from Float Array ---
        var candidates: [DetectionCandidate] = []
        var maxFinalConfidenceFound: Float = 0.0
        let valuesPerDetection = numOutputs // 84
        let detailedLogLimit = 15 // Log details for first N detections
        let scoreLogThreshold: Float = 0.05 // Log details for scores above this

        print("YOLOv8Parser DEBUG: Iterating through \(numDetections) potential detections...")

        for i in 0..<numDetections {
            let baseIndex = i * valuesPerDetection
            // Check bounds using the count of the Float array
            guard baseIndex + valuesPerDetection <= floatData.count else { continue }

            // --- Bounding Box Decoding & Normalization ---
            // Read directly as Float now
            let raw_cx = floatData[baseIndex + 0]; let raw_cy = floatData[baseIndex + 1]
            let raw_w = floatData[baseIndex + 2];  let raw_h = floatData[baseIndex + 3]

            // Normalize assuming raw values are pixel coordinates
            let norm_cx = CGFloat(raw_cx / Float(modelInputSize.width))
            let norm_cy = CGFloat(raw_cy / Float(modelInputSize.height))
            let norm_w = CGFloat(raw_w / Float(modelInputSize.width))
            let norm_h = CGFloat(raw_h / Float(modelInputSize.height))

            // Convert to top-left format
            var x = norm_cx - norm_w / 2.0; var y = norm_cy - norm_h / 2.0
            var w = norm_w; var h = norm_h

            // Clamp coordinates to [0, 1] range
            x = max(0.0, x); y = max(0.0, y)
            w = min(w, 1.0 - x); h = min(h, 1.0 - y)
            guard w > 0, h > 0 else { continue } // Check clamped width/height
            let finalRect = CGRect(x: x, y: y, width: w, height: h)
            // --- End Box Processing ---


            // --- Confidence Calculation ---
            var bestClassIndex = -1; var maxClassLogit: Float = -Float.infinity
            for classIndex in 0..<numClasses {
                let logit = floatData[baseIndex + 4 + classIndex] // Read directly as Float
                if logit > maxClassLogit { maxClassLogit = logit; bestClassIndex = classIndex }
            }
            let confidence = sigmoid(maxClassLogit) // Apply sigmoid to max raw logit
            // --- End Confidence Calculation ---


            // --- DEBUG LOGGING ---
             if i < detailedLogLimit || confidence >= scoreLogThreshold {
                 let boxStr = "[\(String(format:"%.3f",x)), \(String(format:"%.3f",y)), \(String(format:"%.3f",w)), \(String(format:"%.3f",h))]"
                 let classLabelStr = (bestClassIndex >= 0 && bestClassIndex < classLabels.count) ? classLabels[bestClassIndex] : "InvalidIdx"
                 print("   [Detection \(i)] Final Box: \(boxStr) Confidence (Sigmoid): \(String(format: "%.4f", confidence)) [Raw Max Logit: \(String(format:"%.2f",maxClassLogit))] @ Idx: \(bestClassIndex) (\(classLabelStr))")
            }
            if confidence > maxFinalConfidenceFound { maxFinalConfidenceFound = confidence }
            // --- END DEBUG LOGGING ---


            // Filter by CONFIDENCE threshold
            if confidence >= self.confidenceThreshold && bestClassIndex != -1 {
                if bestClassIndex < classLabels.count {
                    let label = classLabels[bestClassIndex]
                    candidates.append(DetectionCandidate(
                        index: i, label: label, confidence: confidence,
                        boundingBox: finalRect, classIndex: bestClassIndex
                    ))
                }
            }
        } // End loop

        print("YOLOv8Parser DEBUG: Max FINAL confidence found: \(String(format: "%.4f", maxFinalConfidenceFound))")
        print("YOLOv8Parser: Decoded \(candidates.count) candidates above threshold (\(self.confidenceThreshold)).")

        // Apply NMS
        let finalDetections = applyNMS(candidates: candidates, iouThreshold: self.iouThreshold)
        return (finalDetections, nil) // Return final detections
    }

    // MARK: - Private Helper Functions

    /// Converts an MLMultiArray to a Swift Array of Floats.
    /// Handles both Float32 and Float16 source types.
    private func convertMultiArrayToFloatArray(_ multiArray: MLMultiArray) throws -> [Float] {
        let count = multiArray.count
        var floatArray = [Float](repeating: 0.0, count: count)

        switch multiArray.dataType {
        case .float32:
            print("YOLOv8Parser DEBUG: Converting Float32 tensor to [Float].")
            guard let pointer = try? UnsafeMutableBufferPointer<Float32>(multiArray) else {
                throw NSError(domain: "YOLOv8Parser", code: 200, userInfo: [NSLocalizedDescriptionKey: "Failed to get Float32 buffer pointer."])
            }
            // Direct copy if types match
            for i in 0..<count {
                floatArray[i] = pointer[i]
            }
        case .float16:
            print("YOLOv8Parser DEBUG: Converting Float16 tensor to [Float].")
            // Float16 available on recent OS versions, handle potential unavailability
             if #available(iOS 14.0, macOS 11.0, *) {
                  guard let pointer = try? UnsafeMutableBufferPointer<Float16>(multiArray) else {
                       throw NSError(domain: "YOLOv8Parser", code: 201, userInfo: [NSLocalizedDescriptionKey: "Failed to get Float16 buffer pointer."])
                  }
                  // Map Float16 values to Float
                  for i in 0..<count {
                       floatArray[i] = Float(pointer[i])
                  }
             } else {
                 // Fallback or error for older OS not supporting Float16 buffer access
                 throw NSError(domain: "YOLOv8Parser", code: 202, userInfo: [NSLocalizedDescriptionKey: "Float16 requires iOS 14+ / macOS 11+"])
             }
        default:
            // Unsupported type
            throw NSError(domain: "YOLOv8Parser", code: 203, userInfo: [NSLocalizedDescriptionKey: "Unsupported MLMultiArray data type: \(multiArray.dataType.rawValue)"])
        }
        return floatArray
    }


    /// Sigmoid Activation Function
    private func sigmoid(_ x: Float) -> Float {
        return 1.0 / (1.0 + exp(-x))
    }

    /// Performs Non-Maximum Suppression
    private func applyNMS(candidates: [DetectionCandidate], iouThreshold: Float) -> [DetectedObject] {
        if candidates.isEmpty { return [] }
        let groupedCandidates = Dictionary(grouping: candidates, by: { $0.classIndex })
        var finalDetections: [DetectedObject] = []
        for (_, group) in groupedCandidates {
            var sortedGroup = group.sorted { $0.confidence > $1.confidence }
            while !sortedGroup.isEmpty {
                let bestCandidate = sortedGroup.removeFirst()
                finalDetections.append(DetectedObject(
                    label: bestCandidate.label, confidence: bestCandidate.confidence,
                    boundingBox: bestCandidate.boundingBox, classIndex: bestCandidate.classIndex
                ))
                sortedGroup.removeAll { calculateIoU(boxA: bestCandidate.boundingBox, boxB: $0.boundingBox) > iouThreshold }
            }
        }
        print("YOLOv8Parser NMS complete. Kept \(finalDetections.count) detections.")
        return finalDetections
    }

    /// Calculates Intersection over Union (IoU)
    private func calculateIoU(boxA: CGRect, boxB: CGRect) -> Float {
        guard boxA.width > 0, boxA.height > 0, boxB.width > 0, boxB.height > 0 else { return 0.0 }
        let ix = max(boxA.minX, boxB.minX); let iy = max(boxA.minY, boxB.minY)
        let iw = min(boxA.maxX, boxB.maxX) - ix; let ih = min(boxA.maxY, boxB.maxY) - iy
        if iw <= 0 || ih <= 0 { return 0.0 }
        let iArea = iw * ih; let areaA = boxA.width * boxA.height; let areaB = boxB.width * boxB.height
        let unionArea = areaA + areaB - iArea
        if unionArea <= 0 { return 0.0 }
        let iou = iArea / unionArea; return max(0.0, min(Float(iou), 1.0))
    }
} // End YOLOv8Parser struct
