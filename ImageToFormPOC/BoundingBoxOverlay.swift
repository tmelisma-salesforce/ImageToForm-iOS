//
//  BoundingBoxOverlay.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25. // Or 4/16/25 if preferred
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Needs Vision framework types

// Ensure Deployment Target is iOS 18.0+ if using new Observation type directly

struct BoundingBoxOverlay: View {
    // Input: Use the NEW Observation Type struct
    let observations: [RecognizedTextObservation]

    var body: some View {
        GeometryReader { geometry in
            ForEach(observations, id: \.uuid) { observation in // Assuming .uuid exists
                // Assuming .boundingBox exists and is CGRect with normalized (0-1) bottom-left origin
                let visionBoundingBox = observation.boundingBox

                // Convert Vision coordinates to SwiftUI coordinates (top-left origin)
                let viewWidth = geometry.size.width
                let viewHeight = geometry.size.height
                let yPosition = (1.0 - visionBoundingBox.origin.y - visionBoundingBox.height) * viewHeight
                let boundingBoxRect = CGRect(
                    x: visionBoundingBox.origin.x * viewWidth,
                    y: yPosition,
                    width: visionBoundingBox.width * viewWidth,
                    height: visionBoundingBox.height * viewHeight
                )

                // Draw the rectangle
                Rectangle()
                    .path(in: boundingBoxRect)
                    .stroke(Color.red, lineWidth: 2)
            }
        } // End GeometryReader
    } // End body
} // End struct

// MARK: - Preview (Optional)
#Preview {
    Rectangle().fill(Color.gray).frame(width: 300, height: 200)
        .overlay(BoundingBoxOverlay(observations: [])) // Pass empty array
}
