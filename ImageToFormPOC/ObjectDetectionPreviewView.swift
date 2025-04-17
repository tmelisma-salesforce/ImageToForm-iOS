//
//  ObjectDetectionPreviewView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Only needed if DetectedObject struct uses Vision types directly

// Ensure DetectedObject struct is accessible (defined globally or imported)
// struct DetectedObject: Identifiable { ... }

struct ObjectDetectionPreviewView: View {
    // MARK: - Properties
    let image: UIImage
    let detectedObjects: [DetectedObject]

    // Callbacks for actions - Type is simple closure
    let onRetake: () -> Void
    let onProceed: () -> Void

    // Environment for dismissing (alternative to callback dismissal)
    // @Environment(\.dismiss) var dismiss // Can use this if preferred

    var body: some View {
        NavigationView {
            VStack {
                Text("Review Detected Objects")
                    .font(.title2)
                    .padding()

                // Display image with bounding boxes for ALL detections
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay(detectionBoundingBoxes) // Apply overlay using helper
                }
                .padding(.horizontal)

                Spacer() // Push buttons down

                HStack {
                    Button("Retake Selfie") {
                        print("Detection Preview: Retake tapped")
                        onRetake() // Call the callback
                        // Dismissal now handled by the caller (ViewModel changing state)
                        // dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Proceed with Analysis") {
                        print("Detection Preview: Proceed tapped")
                        onProceed() // Call the callback
                        // Dismissal now handled by the caller
                        // dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .controlSize(.large)

            } // End VStack
            .navigationTitle("Detection Preview") // Added title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { // Add explicit dismiss if needed via environment
                 ToolbarItem(placement: .navigationBarLeading) {
                     // Example using dismiss environment
                     // Button("Cancel") { dismiss() }
                 }
            }
           // .navigationBarHidden(true) // Optionally hide if buttons are enough

        } // End NavigationView
    } // End body

    /// Computed property to generate the bounding box overlay view
    private var detectionBoundingBoxes: some View {
        GeometryReader { geometry in
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
                        .stroke(Color.yellow, lineWidth: 2) // Yellow for all detections here

                    Text("\(obj.label) (\(String(format: "%.0f%%", obj.confidence * 100)))")
                        .font(.caption2)
                        .padding(2)
                        .background(Color.black.opacity(0.6))
                        .foregroundColor(.yellow)
                        // Adjust offset slightly if needed
                        .offset(x: rect.origin.x, y: rect.origin.y > 14 ? rect.origin.y - 14 : rect.origin.y + 2)
                }
            }
        } // End GeometryReader
    }
} // End struct

// MARK: - Preview
#Preview {
    ObjectDetectionPreviewView(
        image: UIImage(systemName: "person.fill") ?? UIImage(),
        detectedObjects: [ // Ensure DetectedObject definition is available
            DetectedObject(label: "person", confidence: 0.9, boundingBox: CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8), classIndex: 0),
            DetectedObject(label: "helmet", confidence: 0.7, boundingBox: CGRect(x: 0.3, y: 0.05, width: 0.4, height: 0.2), classIndex: 32) // Example index
        ],
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}
