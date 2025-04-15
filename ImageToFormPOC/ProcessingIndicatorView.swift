//
//  ProcessingIndicatorView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//


//
//  ProcessingIndicatorView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25. // Update date if needed
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct ProcessingIndicatorView: View {
     var body: some View {
        ZStack {
            // Semi-transparent background overlay
            Color(white: 0, opacity: 0.5)
                .edgesIgnoringSafeArea(.all)
            // Spinner with text
            ProgressView("Processing...")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white) // Ensure text is visible
                .cornerRadius(10)
                .shadow(radius: 10)
        }
    }
}