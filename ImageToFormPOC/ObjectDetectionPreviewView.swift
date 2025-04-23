//
//  ObjectDetectionPreviewView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
// DetectedObject struct is defined in ProtectiveGearViewModel.swift

struct ObjectDetectionPreviewView: View {
    // MARK: - Properties
    let image: UIImage
    let detectedObjects: [DetectedObject] // Already filtered list
    let previewMessage: String?
    let isFrontCameraImage: Bool // Flag to know the source

    // Callbacks for actions
    let onRetake: () -> Void
    let onProceed: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                Text("Review Detection Results")
                    .font(.title2)
                    .padding(.top)

                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        // Pass the flag to the overlay
                        .overlay(detectionBoundingBoxesOverlay(isFrontCamera: isFrontCameraImage))
                }
                .padding(.horizontal)

                if let message = previewMessage {
                    Text(message)
                        .font(.headline)
                        .foregroundColor(message.contains("Flip-flops") ? .red : .secondary)
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                HStack {
                    Button("Retake Photo") {
                        print("Detection Preview: Retake tapped")
                        onRetake()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Proceed") {
                        print("Detection Preview: Proceed tapped")
                        onProceed()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .controlSize(.large)

            } // End VStack
            .navigationTitle("Detection Preview")
            .navigationBarTitleDisplayMode(.inline)
        } // End NavigationView
    } // End body

    // MARK: - Helper Functions

    /// Calculates the final drawing rectangle in view coordinates.
    private func calculateRect(for obj: DetectedObject, in geometry: GeometryProxy, isFrontCamera: Bool) -> CGRect {
        let normalizedBox = obj.boundingBox // CGRect (0-1) with Vision's origin (bottom-left)

        // --- Revised Coordinate Transformation ---

        // 1. Convert Y from Vision's bottom-left to SwiftUI's top-left origin
        let y_swiftui_norm = 1.0 - normalizedBox.origin.y - normalizedBox.height

        // 2. Use original X coordinate directly (Hypothesis: Mirroring handled elsewhere)
        let x_swiftui_norm = normalizedBox.origin.x
        print("DEBUG Transform (\(isFrontCamera ? "Front" : "Rear")): Using Original X=\(x_swiftui_norm), Flipped Y=\(y_swiftui_norm)")


        // Keep original width and height
        let width_swiftui_norm = normalizedBox.width
        let height_swiftui_norm = normalizedBox.height

        // --- End Transformation ---


        // 3. Scale normalized coordinates to view coordinates
        let viewWidth = geometry.size.width
        let viewHeight = geometry.size.height
        let finalRect = CGRect(
            x: x_swiftui_norm * viewWidth,
            y: y_swiftui_norm * viewHeight,
            width: width_swiftui_norm * viewWidth,
            height: height_swiftui_norm * viewHeight
        )

        // Clamp values to be within bounds just in case calculations go slightly off
        let clampedRect = CGRect(
            x: max(0, min(finalRect.origin.x, viewWidth - finalRect.width)),
            y: max(0, min(finalRect.origin.y, viewHeight - finalRect.height)),
            width: min(finalRect.width, viewWidth - max(0, finalRect.origin.x)),
            height: min(finalRect.height, viewHeight - max(0, finalRect.origin.y))
        )


        print("DEBUG Final Scaled Rect: \(clampedRect)")
        return clampedRect
    }

    /// Generates the overlay view containing bounding boxes.
    private func detectionBoundingBoxesOverlay(isFrontCamera: Bool) -> some View {
        GeometryReader { geometry in
            // Check if objects exist *before* iterating
            if !detectedObjects.isEmpty {
                ForEach(detectedObjects) { obj in
                    // Calculate rect using the helper function
                    let rect = calculateRect(for: obj, in: geometry, isFrontCamera: isFrontCamera)

                    // Return the View for this object if the rect is valid
                    if rect.width > 0 && rect.height > 0 {
                        ZStack(alignment: .topLeading) {
                            Rectangle()
                                .path(in: rect)
                                .stroke(obj.label == "flip-flops" ? Color.red : Color.yellow, lineWidth: 2)

                            Text("\(obj.label) (\(String(format: "%.0f%%", obj.confidence * 100)))")
                                .font(.caption2)
                                .padding(2)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(obj.label == "flip-flops" ? .red : .yellow)
                                // Adjust label position slightly to stay within bounds
                                .offset(x: rect.origin.x, y: max(0, rect.origin.y - 14))

                        }
                    } else {
                        EmptyView() // Don't draw if rect is invalid
                    }
                } // End ForEach
            } else {
                EmptyView() // Return an empty view if no objects
            } // End if !detectedObjects.isEmpty
        } // End GeometryReader
    } // End detectionBoundingBoxesOverlay func
} // End struct

// MARK: - Preview
// (Previews remain the same)
#Preview("Front Camera - Gear Found") {
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "person.fill") ?? UIImage(),
        detectedObjects: [
            DetectedObject(label: "helmet", confidence: 0.9, boundingBox: CGRect(x: 0.3, y: 0.05, width: 0.4, height: 0.2)),
            DetectedObject(label: "glove", confidence: 0.7, boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.2))
        ],
        previewMessage: nil,
        isFrontCameraImage: true,
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}

#Preview("Front Camera - No Gear") {
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "person.fill") ?? UIImage(),
        detectedObjects: [],
        previewMessage: "No helmet or gloves detected.",
        isFrontCameraImage: true,
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}

#Preview("Rear Camera - FlipFlops") {
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "figure.walk") ?? UIImage(),
        detectedObjects: [
             DetectedObject(label: "flip-flops", confidence: 0.85, boundingBox: CGRect(x: 0.3, y: 0.8, width: 0.4, height: 0.15))
        ],
        previewMessage: "Flip-flops detected. Not suitable protective gear.",
        isFrontCameraImage: false,
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}

#Preview("Rear Camera - Boots Found") {
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "figure.walk") ?? UIImage(),
        detectedObjects: [
             DetectedObject(label: "boots", confidence: 0.85, boundingBox: CGRect(x: 0.3, y: 0.7, width: 0.4, height: 0.25))
        ],
        previewMessage: nil,
        isFrontCameraImage: false,
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}

