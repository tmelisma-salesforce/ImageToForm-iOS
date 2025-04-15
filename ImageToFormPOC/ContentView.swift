//
//  ContentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Import Vision early, as it will be needed for results state

struct ContentView: View {

    // MARK: - State Variables
    // These control the UI's state and data flow

    // Controls presentation of the camera/image picker view
    @State private var showCamera = false

    // Holds the image captured by the user (nil initially)
    @State private var capturedImage: UIImage? = nil

    // Holds the text recognition results from Vision (empty initially)
    @State private var visionResults: [VNRecognizedTextObservation] = []

    // MARK: - Body
    var body: some View {
        // Use a NavigationView for a title bar (optional but good practice)
        NavigationView {
            // Main layout container, arranges children vertically
            VStack {
                // --- Welcome View Content ---
                // Spacers help center the welcome message vertically
                Spacer()

                Text("Image Text Scanner POC")
                    .font(.largeTitle) // Make the title prominent
                    .padding(.bottom, 5) // Add a little space below title

                Text("Tap 'Start Scan' to capture an image and extract text.")
                    .font(.body) // Standard body text
                    .foregroundColor(.secondary) // Slightly muted color
                    .multilineTextAlignment(.center) // Center align if text wraps
                    .padding([.leading, .trailing]) // Add horizontal padding

                Spacer() // Pushes button towards the bottom

                // Button to initiate the scanning process
                Button("Start Scan") {
                    // Action to perform when button is tapped:
                    // 1. Reset any previous scan results
                    self.capturedImage = nil
                    self.visionResults = []
                    // 2. Set the state variable to trigger the presentation of the camera view
                    self.showCamera = true
                }
                .padding() // Add padding around the button text
                .buttonStyle(.borderedProminent) // Use a visually distinct style

                Spacer() // Add a spacer at the bottom
                // --- End Welcome View ---
            } // End of main VStack
            .navigationTitle("Welcome") // Set the title for the welcome screen
            .navigationBarTitleDisplayMode(.inline)

            // Modifier to present the Camera View (as a full screen cover)
            // This view appears when 'showCamera' becomes true
            .fullScreenCover(isPresented: $showCamera) {
                // Content of the modal view:
                // In the next step, this will be our 'ImagePicker'
                // For now, it's just a placeholder Text view
                ZStack { // Use ZStack to overlay a dismiss button if needed
                    Color.black.edgesIgnoringSafeArea(.all) // Background for placeholder
                    VStack {
                         Text("Camera View Placeholder (Step 2)")
                            .foregroundColor(.white)
                            .padding()
                         // Simple dismiss button for placeholder
                         Button("Dismiss") {
                              self.showCamera = false
                         }
                         .padding()
                         .buttonStyle(.bordered)
                         .tint(.white)
                    }
                }
            } // End of .fullScreenCover

        } // End of NavigationView
        // On iPad, NavigationView might show sidebar - use stack style if needed
        .navigationViewStyle(.stack)

    } // End of body
} // End of ContentView struct

// MARK: - Preview
// Provides the preview in Xcode Canvas
#Preview {
    ContentView()
}
