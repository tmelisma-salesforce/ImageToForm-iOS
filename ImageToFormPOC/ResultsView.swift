//
//  ResultsView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25. // Update date if needed
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // For observation type

struct ResultsView: View {
    // Bindings needed to display results
    @Binding var capturedImage: UIImage? // Still allow reset via ContentView
    @Binding var visionResults: [RecognizedTextObservation] // Use NEW type
    @Binding var isProcessing: Bool
    @Binding var classificationLabel: String // Display classification

    // REMOVED: @Binding var showCamera: Bool // This binding is not used here

    var body: some View {
        VStack {
            // Display Classification Result First
            Text("Detected: \(classificationLabel.isEmpty ? "N/A" : classificationLabel)")
                 .font(.title3)
                 .padding(.top)
                 .padding(.horizontal)

            // Display Image and Bounding Boxes
            ZStack {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        // Apply overlay (ensure BoundingBoxOverlay.swift exists)
                        .overlay(BoundingBoxOverlay(observations: visionResults))
                } else {
                    Text("Error displaying image.")
                }
            }
            .frame(minHeight: 150, maxHeight: 300)
            .border(Color.gray, width: 1)
            .padding([.leading, .trailing, .bottom])

            // Display OCR Text List
            List {
                Section("Extracted Text:") {
                    if isProcessing { // Check processing first
                         Text("Processing...")
                            .foregroundColor(.gray)
                    } else if visionResults.isEmpty {
                         Text("No text found.")
                            .foregroundColor(.gray)
                    } else {
                         ForEach(visionResults, id: \.uuid) { observation in // Assumes .uuid
                             // Assumes .topCandidates exists on new type
                             Text(observation.topCandidates(1).first?.string ?? "Read Error")
                         }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        } // End Results VStack
    } // End body
} // End ResultsView
