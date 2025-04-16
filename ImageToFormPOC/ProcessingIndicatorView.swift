//
//  ProcessingIndicatorView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25. // Update date if needed
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct ProcessingIndicatorView: View {
     var body: some View {
        // Use ZStack to layer the background and the progress indicator
        ZStack {
            // Semi-transparent background to dim the underlying view
            Color(white: 0, opacity: 0.5)
                .edgesIgnoringSafeArea(.all) // Extend dimming to screen edges

            // The actual indicator
            ProgressView("Processing...") // Standard spinner with text label
                .progressViewStyle(CircularProgressViewStyle(tint: .white)) // White spinner
                .padding() // Add padding inside the background
                .background(Color.black.opacity(0.7)) // Dark semi-transparent background for the box
                .foregroundColor(.white) // Make the "Processing..." text white
                .cornerRadius(10) // Round the corners of the background box
                .shadow(radius: 10) // Add a subtle shadow
        }
    }
}

// MARK: - Preview
#Preview {
    // Show the indicator against a dummy background for preview
    ZStack {
        Color.blue // Example background
        ProcessingIndicatorView()
    }
}
