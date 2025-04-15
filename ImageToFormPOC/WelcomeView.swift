//
//  WelcomeView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//


//
//  WelcomeView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25. // Update date if needed
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // For observation type in binding

struct WelcomeView: View {
    // Needs bindings to trigger camera and reset state in ContentView
    @Binding var showCamera: Bool
    @Binding var capturedImage: UIImage?
    @Binding var visionResults: [RecognizedTextObservation]
    @Binding var classificationLabel: String

    var body: some View {
        VStack {
            Spacer()
            Text("Image Text Scanner POC")
                .font(.largeTitle)
                .padding(.bottom, 5)
            Text("Tap 'Start Scan' to capture an image and extract text.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding([.leading, .trailing])
            Spacer()
            Button("Start Scan") {
                // Reset all relevant states before showing camera
                self.capturedImage = nil
                self.visionResults = []
                self.classificationLabel = ""
                self.showCamera = true
            }
            .padding()
            .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}
