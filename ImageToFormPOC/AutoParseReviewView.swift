//
//  AutoParseReviewView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct AutoParseReviewView: View {
    // MARK: - Properties
    @Binding var isPresented: Bool // To dismiss this view
    let autoParsedData: [String: String] // Data to display
    let onAccept: () -> Void // Callback when user accepts

    // Helper for sorted display order
    private var sortedKeys: [String] {
        autoParsedData.keys.sorted()
    }

    var body: some View {
        NavigationView { // Embed in Nav for Title and potential Toolbar
            VStack(alignment: .leading) {
                Text("The following values were automatically detected. Please review.")
                    .padding()

                // Display list of auto-parsed values
                if autoParsedData.isEmpty {
                    Text("No values were automatically detected.")
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    List {
                        ForEach(sortedKeys, id: \.self) { key in
                            HStack {
                                Text("\(userFriendlyFieldName(key)):")
                                    .fontWeight(.semibold)
                                Spacer()
                                Text(autoParsedData[key] ?? "Error")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .listStyle(.plain) // Use plain style for simple list
                }

                Spacer() // Pushes button down

                // Accept button triggers callback and dismisses
                Button("Accept & Continue") {
                    print("Auto-parse results accepted.")
                    onAccept() // Trigger next step in ViewModel
                    isPresented = false // Dismiss this view
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding()

            } // End VStack
            .navigationTitle("Review Auto-Detected") // Concise title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Cancel just dismisses this review sheet
                    Button("Cancel") {
                        print("Cancelling Auto-Parse Review.")
                         isPresented = false
                    }
                }
            }
        } // End NavigationView
    } // End body

    /// Helper to make dictionary keys more readable
    private func userFriendlyFieldName(_ key: String) -> String {
        switch key {
        case "mfgDate": return "Mfg Date"
        case "voltage": return "Voltage"
        case "amps": return "Amps"
        case "pressure": return "Pressure"
        default: return key.capitalized
        }
    }
}

// MARK: - Preview
#Preview {
    AutoParseReviewView(
        isPresented: .constant(true),
        autoParsedData: ["voltage": "460 V", "amps": "32 A", "mfgDate": "2023-11", "pressure": "175 PSI"],
        onAccept: { print("Preview Accept") }
    )
}
