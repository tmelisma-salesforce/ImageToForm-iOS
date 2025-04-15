//
//  BoundingBoxOverlay.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Needs Vision framework types

// *** TYPE CHANGE HERE ***
// Input is now an array of the NEW observation struct
struct BoundingBoxOverlay: View {
    let observations: [RecognizedTextObservation] // Use NEW type

    var body: some View {
        GeometryReader { geometry in
            ForEach(observations, id: \.uuid) { observation in // Assuming new type has uuid
                // *** ASSUMPTION HERE ***
                // Assuming new RecognizedTextObservation struct still has 'boundingBox'
                // with the same normalized coordinate system (0-1, bottom-left origin).
                // If not, this calculation needs adjustment based on actual properties.
                let visionBoundingBox = observation.boundingBox

                let viewWidth = geometry.size.width
                let viewHeight = geometry.size.height
                let yPosition = (1.0 - visionBoundingBox.origin.y - visionBoundingBox.height) * viewHeight
                let boundingBoxRect = CGRect(
                    x: visionBoundingBox.origin.x * viewWidth,
                    y: yPosition,
                    width: visionBoundingBox.width * viewWidth,
                    height: visionBoundingBox.height * viewHeight
                )

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
