//
//  ObjectDetectionPreviewView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
// Vision framework import removed as it's not directly needed by this view anymore.
// DetectedObject struct is assumed available (defined in ProtectiveGearViewModel.swift).

struct ObjectDetectionPreviewView: View {
    // MARK: - Properties
    let image: UIImage
    // Receives the ALREADY FILTERED list of objects relevant to this preview
    // This now uses the DetectedObject struct defined in ProtectiveGearViewModel
    let detectedObjects: [DetectedObject]
    // Receives the message to display (e.g., "No gear detected", "Flip-flops detected")
    let previewMessage: String?

    // Callbacks for actions
    let onRetake: () -> Void
    let onProceed: () -> Void

    var body: some View {
        NavigationView {
            VStack {
                Text("Review Detection Results") // Generic title
                    .font(.title2)
                    .padding(.top) // Add padding top

                // Display image with bounding boxes for FILTERED detections
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        // Apply overlay using helper, passing the filtered list
                        .overlay(detectionBoundingBoxes)
                }
                .padding(.horizontal)

                // --- Display Preview Message ---
                if let message = previewMessage {
                    Text(message)
                        .font(.headline)
                        .foregroundColor(message.contains("Flip-flops") ? .red : .secondary) // Highlight flip-flop message
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .multilineTextAlignment(.center)
                }
                // --- End Preview Message ---

                Spacer() // Push buttons down

                HStack {
                    Button("Retake Photo") { // Changed label for clarity
                        print("Detection Preview: Retake tapped")
                        onRetake() // Call the callback (ViewModel handles dismissal)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Proceed") { // Changed label for clarity
                        print("Detection Preview: Proceed tapped")
                        onProceed() // Call the callback (ViewModel handles dismissal)
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

    /// Computed property to generate the bounding box overlay view
    /// Now uses the filtered `detectedObjects` passed into the view.
    private var detectionBoundingBoxes: some View {
        GeometryReader { geometry in
            // Only draw boxes if there are objects to display
            if !detectedObjects.isEmpty {
                ForEach(detectedObjects) { obj in
                    // Assuming obj.boundingBox is normalized [0-1], top-left origin
                    let viewWidth = geometry.size.width
                    let viewHeight = geometry.size.height
                    let rect = CGRect(
                        x: obj.boundingBox.origin.x * viewWidth,
                        y: obj.boundingBox.origin.y * viewHeight,
                        width: obj.boundingBox.width * viewWidth,
                        height: obj.boundingBox.height * viewHeight
                    )

                    // Draw rectangle and label
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .path(in: rect)
                            .stroke(obj.label == "flip-flops" ? Color.red : Color.yellow, lineWidth: 2) // Highlight flip-flops

                        Text("\(obj.label) (\(String(format: "%.0f%%", obj.confidence * 100)))")
                            .font(.caption2)
                            .padding(2)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(obj.label == "flip-flops" ? .red : .yellow) // Highlight flip-flops
                            // Adjust offset slightly if needed
                            .offset(x: rect.origin.x, y: rect.origin.y > 14 ? rect.origin.y - 14 : rect.origin.y + 2)
                    }
                }
            } else {
                // If detectedObjects is empty, draw nothing (message is handled outside overlay)
                EmptyView()
            }
        } // End GeometryReader
    }
} // End struct

// MARK: - Preview
#Preview {
    // Example 1: Helmet/Glove found
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "person.fill") ?? UIImage(),
        detectedObjects: [
            // --- CORRECTED: Removed classIndex argument ---
            DetectedObject(label: "helmet", confidence: 0.9, boundingBox: CGRect(x: 0.3, y: 0.05, width: 0.4, height: 0.2)),
            DetectedObject(label: "glove", confidence: 0.7, boundingBox: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.2))
            // --- END CORRECTION ---
        ],
        previewMessage: nil, // No specific message needed if items found
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}

#Preview("No Gear") { // Added label for clarity
    // Example 2: No Helmet/Glove found
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "person.fill") ?? UIImage(),
        detectedObjects: [], // Empty list passed in
        previewMessage: "No helmet or gloves detected.", // Message provided by ViewModel
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}

#Preview("FlipFlops") { // Added label for clarity
    // Example 3: Flip-flops found
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "figure.walk") ?? UIImage(),
        detectedObjects: [
             // --- CORRECTED: Removed classIndex argument ---
             DetectedObject(label: "flip-flops", confidence: 0.85, boundingBox: CGRect(x: 0.3, y: 0.8, width: 0.4, height: 0.15))
             // --- END CORRECTION ---
        ],
        previewMessage: "Flip-flops detected. Not suitable protective gear.", // Message provided by ViewModel
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}

