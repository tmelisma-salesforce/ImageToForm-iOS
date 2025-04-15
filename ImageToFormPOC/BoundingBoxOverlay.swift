//
//  BoundingBoxOverlay.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Needs Vision framework types

struct BoundingBoxOverlay: View {
    // Input: Use the NEW Observation Type
    let observations: [RecognizedTextObservation]

    var body: some View {
        GeometryReader { geometry in
            ForEach(observations, id: \.uuid) { observation in // Assumes .uuid
                // Assuming .boundingBox exists and is compatible
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
}

// MARK: - Preview (Optional)
#Preview {
    Rectangle().fill(Color.gray).frame(width: 300, height: 200)
        .overlay(BoundingBoxOverlay(observations: [])) // Pass empty array
}
