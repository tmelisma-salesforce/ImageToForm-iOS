//
//  BoundingBoxOverlay.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Needs Vision framework types like VNRecognizedTextObservation

struct BoundingBoxOverlay: View {
    // Input: The observations containing bounding boxes from the Vision request
    let observations: [VNRecognizedTextObservation]

    var body: some View {
        // GeometryReader provides the available size for the overlay view
        GeometryReader { geometry in
            // Loop through each text observation result
            ForEach(observations, id: \.uuid) { observation in
                // Get the normalized bounding box (0-1 range) from Vision
                let visionBoundingBox = observation.boundingBox

                // --- Coordinate Conversion ---
                // Convert Vision's coordinate system (origin at bottom-left)
                // to SwiftUI's coordinate system (origin at top-left)
                // inside the geometry reader's frame size.
                let viewWidth = geometry.size.width
                let viewHeight = geometry.size.height
                let yPosition = (1.0 - visionBoundingBox.origin.y - visionBoundingBox.height) * viewHeight
                let boundingBoxRect = CGRect(
                    x: visionBoundingBox.origin.x * viewWidth,
                    y: yPosition,
                    width: visionBoundingBox.width * viewWidth,
                    height: visionBoundingBox.height * viewHeight
                )
                // --- End Coordinate Conversion ---

                // Draw the rectangle shape for the bounding box
                Rectangle()
                    .path(in: boundingBoxRect) // Define the shape using the calculated CGRect
                    .stroke(Color.red, lineWidth: 2) // Style the box with a red outline
            }
        } // End GeometryReader
    } // End body
} // End struct

// MARK: - Preview (Optional)
#Preview {
    // Example with a dummy observation for preview canvas
    Rectangle().fill(Color.gray).frame(width: 300, height: 200) // Dummy background
        .overlay(BoundingBoxOverlay(observations: [])) // Pass empty array for preview
}
