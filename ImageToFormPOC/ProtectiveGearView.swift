//
//  ProtectiveGearView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
// UIKit needed for UIImage later, Vision will be needed for detection
import UIKit
import Vision

struct ProtectiveGearView: View {

    // MARK: - State Variables
    @State private var showFrontCamera = false
    @State private var selfieImage: UIImage? = nil
    @State private var isProcessing = false // Will be used for Object Detection later
    // State for detection results will be added later

    // Define required gear
    let requiredGear = ["Helmet", "Gloves", "Boots"]

    var body: some View {
        VStack(alignment: .leading) { // Main container
            Text("Required Personal Protective Equipment (PPE):")
                .font(.headline)
                .padding(.bottom, 5)

            // List the required gear
            ForEach(requiredGear, id: \.self) { item in
                Label(item, systemImage: "shield.lefthalf.filled") // Example icon
            }
            .padding(.leading)
            .padding(.bottom) // Padding applied correctly to ForEach content

            Divider()

            Text("Capture Selfie:")
                .font(.headline)
                .padding(.bottom, 5)

            // Conditional Image Display
            if let image = selfieImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 300) // Limit display size
                    .overlay(alignment: .topTrailing) {
                         Button { selfieImage = nil /* Clear results too */ } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.gray).background(Color.white.opacity(0.8)).clipShape(Circle()).padding(5) }
                     }
                    // Removed misplaced padding from here
            } else {
                Text("Take a selfie to check your gear.")
                    .foregroundColor(.gray)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color(uiColor: .systemGray6)))
                 // Removed misplaced padding from here
            }
            // *** The misplaced .padding(.bottom) likely occurred right around here and has been removed ***

            // Button to trigger selfie capture (Unchanged)
            Button {
                self.selfieImage = nil // Clear previous image
                // Clear detection results state here later
                self.showFrontCamera = true // Trigger sheet/cover
            } label: {
                Label(selfieImage == nil ? "Check My Gear (Take Selfie)" : "Retake Selfie", systemImage: "person.crop.square.badge.camera")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity) // Make button wide
            .padding(.top) // Add padding above the button

            // Placeholder for results display (Step 10)
            Spacer() // Pushes content up

        } // End main VStack
        .padding() // Overall padding for the VStack content
        .navigationTitle("Verify Protective Gear")
        // Present ImagePicker requesting FRONT camera
        .fullScreenCover(isPresented: $showFrontCamera) {
            ImagePicker(selectedImage: $selfieImage, isFrontCamera: true) // Pass true here
        }
        // onChange + Task for object detection will be added in Step 9
         .onChange(of: selfieImage) { _, newImage in
              if newImage != nil {
                   print("ProtectiveGearView: Selfie captured. Ready for Step 9 (Object Detection).")
                   // Launch Object Detection Task here in next step
              }
         }
         // Overlay for processing indicator will be added in Step 9
         // .overlay { if isProcessing { ProcessingIndicatorView() } }

    } // End body
} // End struct

#Preview {
    NavigationView {
        ProtectiveGearView()
    }
}
