//
//  ContentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25. // Updated date
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct ContentView: View {

    // ContentView now acts as the main navigation hub.
    // State related to scanning/results will live in the specific feature views later.

    var body: some View {
        // Use NavigationStack for push/pop navigation between menu and features
        NavigationStack {
            VStack(spacing: 20) { // Add some spacing between elements
                Spacer() // Pushes content down slightly from top

                Text("Salesforce Field Service")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 30) // Add space below title

                // NavigationLink navigates to a destination view when tapped
                NavigationLink {
                    // Destination View for the first option
                    ProtectiveGearView()
                } label: {
                    // How the link looks
                    Text("Verify Protective Gear")
                        .frame(maxWidth: .infinity) // Make button wide
                }
                .buttonStyle(.borderedProminent) // Style as a prominent button
                .controlSize(.large) // Make button larger

                NavigationLink {
                    // Destination View for the second option
                    MeterReadingView()
                } label: {
                    Text("Read Meter")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                NavigationLink {
                    // Destination View for the third option
                    EquipmentInfoView()
                } label: {
                    Text("Capture Equipment Info")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Spacer() // Pushes buttons towards the center/top
                Spacer() // Add more space at the bottom

            } // End main VStack
            .padding() // Add padding around the VStack content
            // Keep the title consistent or remove if redundant with Text above
            // .navigationTitle("Field Service Menu")
            // .navigationBarTitleDisplayMode(.inline)

        } // End NavigationStack
    } // End body
} // End ContentView

// MARK: - Preview
#Preview {
    ContentView()
}
