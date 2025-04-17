//
//  OcrPreviewView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision

struct OcrPreviewView: View {
    // Data needed for display
    let image: UIImage
    let observations: [RecognizedTextObservation]

    // Callbacks for actions
    let onRetake: () -> Void
    let onProceed: () -> Void

    // Environment for dismissing
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        NavigationView { // Embed in Nav for toolbar items
            VStack {
                Text("Review Scanned Text")
                    .font(.title2)
                    .padding()

                // Display image with bounding boxes
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay(BoundingBoxOverlay(observations: observations)) // Reuse overlay
                }
                .padding(.horizontal)

                Spacer() // Push buttons down

                HStack {
                    Button("Retake Photo") {
                        print("Preview: Retake tapped")
                        onRetake() // Call the callback
                        presentationMode.wrappedValue.dismiss() // Dismiss this preview
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Proceed with Scan") {
                        print("Preview: Proceed tapped")
                        onProceed() // Call the callback
                        presentationMode.wrappedValue.dismiss() // Dismiss this preview
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .controlSize(.large)

            }
            .navigationBarHidden(true) // Hide nav bar if buttons are sufficient
            // Alternatively, use toolbar items:
            // .navigationTitle("Confirm Scan")
            // .navigationBarTitleDisplayMode(.inline)
            // .toolbar {
            //     ToolbarItem(placement: .navigationBarLeading) { Button("Retake") { onRetake(); presentationMode.wrappedValue.dismiss() } }
            //     ToolbarItem(placement: .navigationBarTrailing) { Button("Proceed") { onProceed(); presentationMode.wrappedValue.dismiss() }.buttonStyle(.borderedProminent) }
            // }
        }
    }
}

// Preview needs dummy data
#Preview {
    OcrPreviewView(
        image: UIImage(systemName: "doc.text.image") ?? UIImage(), // Placeholder image
        observations: [], // Empty observations
        onRetake: { print("Preview Retake") },
        onProceed: { print("Preview Proceed") }
    )
}
