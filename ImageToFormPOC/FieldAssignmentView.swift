//
//  FieldAssignmentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct FieldAssignmentView: View {
    // MARK: - Properties
    @Binding var isPresented: Bool
    let allOcrStrings: [String] // This now receives the FILTERED list (excluding already assigned)
    let fieldName: String
    let onAssign: (String?) -> Void

    // MARK: - Local State
    @State private var manualEntry: String = ""
    @State private var recentlySelected: String? = nil // Track tapped string for feedback
    @State private var isAssigning: Bool = false // Prevent double taps during delay

    var body: some View {
        NavigationView {
            VStack(alignment: .leading) {
                // Header
                Text("Assign Value For: \(fieldName)")
                    .font(.headline)
                    .padding()

                Divider()

                // Manual Entry
                HStack {
                    TextField("Enter Manually or Select Below", text: $manualEntry)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isAssigning) // Disable while assigning
                    Button("Assign Manual") {
                        assignValue(manualEntry)
                    }
                    .buttonStyle(.bordered)
                    .disabled(manualEntry.isEmpty || isAssigning)
                }
                .padding([.horizontal, .bottom])

                // OCR Results List Header
                Text("Select from OCR Results:")
                    .font(.caption)
                    .padding(.horizontal)

                // Scrollable list of OCR results
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        // Only show strings passed in (already filtered by parent)
                        ForEach(allOcrStrings, id: \.self) { ocrString in
                            Button {
                                // Action: Visually select, then assign after delay
                                selectAndAssign(ocrString)
                            } label: {
                                HStack {
                                    Text(ocrString)
                                    Spacer()
                                    // Show temporary checkmark during selection animation
                                    if recentlySelected == ocrString {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                // Highlight background during selection animation
                                .background(recentlySelected == ocrString ? Color.green.opacity(0.3) : Color(uiColor: .systemGray6))
                                .cornerRadius(5)
                                // Apply scaling effect during selection
                                .scaleEffect(recentlySelected == ocrString ? 1.03 : 1.0)

                            }
                            .buttonStyle(.plain)
                            .disabled(isAssigning) // Disable buttons during assignment delay
                        }
                    }
                    .padding(.horizontal) // Padding for the list items
                } // End ScrollView
                .animation(.easeInOut(duration: 0.2), value: recentlySelected) // Animate selection changes

                Divider()

                // Skip Button
                HStack {
                    Spacer()
                    Button("Skip Field") {
                       assignValue(nil) // Assign nil for skip
                    }
                    .padding([.horizontal, .top])
                    .disabled(isAssigning)
                    Spacer()
                }

            } // End main VStack
            .navigationTitle("Assign \(fieldName)") // More specific title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel All") {
                        print("Cancelling assignment flow.")
                        isPresented = false // Dismiss the sheet entirely
                    }
                    .disabled(isAssigning)
                }
            }
        } // End NavigationView
    } // End body

    // MARK: - Helper Functions

    /// Handles assignment with visual feedback and delay
    private func selectAndAssign(_ value: String?) {
        guard !isAssigning else { return } // Prevent double taps

        isAssigning = true // Disable interactions
        recentlySelected = value // Trigger visual feedback

        // Delay allows user to see selection before sheet moves on
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onAssign(value) // Call parent's assignment logic
            // Reset local state *if* the view hasn't been dismissed yet
            // This might not be strictly necessary if the parent dismisses/recreates view
             if isPresented { // Check if still presented
                 recentlySelected = nil
                 isAssigning = false
             }
        }
    }

     /// Handles manual assignment trigger
     private func assignValue(_ value: String?) {
         guard !isAssigning else { return }
         isAssigning = true // Disable interactions

         // For manual/skip, call parent immediately (no visual feedback needed here)
         onAssign(value)

         // Reset local state if view isn't immediately dismissed by parent
          if isPresented {
              if value != nil && value == manualEntry { // Clear manual entry field if assigned
                  manualEntry = ""
              }
              recentlySelected = nil
              isAssigning = false
          }
     }

} // End struct
