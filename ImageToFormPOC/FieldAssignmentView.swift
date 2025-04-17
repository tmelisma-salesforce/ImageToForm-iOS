//
//  FieldAssignmentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct FieldAssignmentView: View {
    // MARK: - Properties Passed In
    @Binding var isPresented: Bool
    let allOcrStrings: [String] // Filtered list (excluding already assigned)
    let fieldName: String
    let onAssign: (String?) -> Void
    let autoParsedData: [String: String] // Auto-parsed data to display

    // MARK: - Local State
    @State private var manualEntry: String = ""
    @State private var recentlySelected: String? = nil // For selection animation

    // Helper for stable display order of auto-parsed data
    private var sortedAutoParsedKeys: [String] {
        autoParsedData.keys.sorted()
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) { // Manage spacing with padding

                // Header showing which field to assign
                VStack(alignment: .leading) {
                    Text("Assign Value For:")
                        .font(.headline).foregroundColor(.gray)
                    Text(fieldName)
                        .font(.title).fontWeight(.bold)
                }
                .padding(.horizontal).padding(.top).padding(.bottom, 10)

                Divider()

                // Section displaying values already auto-parsed
                 if !autoParsedData.isEmpty {
                     VStack(alignment: .leading) {
                         Text("Auto-Detected Values:")
                             .font(.caption).foregroundColor(.gray).padding(.bottom, 1)
                         ForEach(sortedAutoParsedKeys, id: \.self) { key in
                             HStack {
                                 Text("\(userFriendlyFieldName(key)):").font(.caption.bold())
                                 Text(autoParsedData[key] ?? "N/A").font(.caption)
                                 Spacer()
                             }
                         }
                     }
                     .padding(.horizontal).padding(.vertical, 8)
                     .background(Color.blue.opacity(0.1)).cornerRadius(5)
                     .padding([.horizontal, .bottom])
                     Divider()
                 }

                // Manual entry option
                HStack {
                    TextField("Enter Manually or Select Below", text: $manualEntry)
                        .textFieldStyle(.roundedBorder)
                    Button("Assign Manual") { assignValue(manualEntry) }
                        .buttonStyle(.bordered)
                        .disabled(manualEntry.isEmpty)
                }
                .padding([.horizontal, .bottom]).padding(.top)

                // Header for OCR list
                Text("Select from OCR Results:")
                    .font(.caption)
                    .padding(.horizontal)
                    .padding(.bottom, 5)

                // Scrollable list of available OCR results
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        // Iterate over filtered strings passed in
                        ForEach(allOcrStrings, id: \.self) { ocrString in
                            ocrStringButton(ocrString) // Use helper view builder
                        }
                    }
                    .padding(.horizontal).padding(.bottom)
                }
                .animation(.easeInOut(duration: 0.2), value: recentlySelected) // Animate selection highlight

                Divider().padding(.top, 5)

                // Skip button
                HStack {
                    Spacer()
                    Button("Skip Field") { assignValue(nil) } // Call helper with nil
                    Spacer()
                }
                .padding()

            } // End main VStack
            .navigationTitle("Assign \(fieldName)") // Set dynamic title
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    // Cancel button dismisses the entire assignment flow
                    Button("Cancel All") {
                        print("Cancelling assignment flow.")
                        isPresented = false
                    }
                }
            }
        } // End NavigationView
    } // End body

    // MARK: - Subview Builder for List Buttons
    /// Creates a button for each OCR string in the list.
    @ViewBuilder
    private func ocrStringButton(_ ocrString: String) -> some View {
        Button {
            selectAndAssign(ocrString) // Call helper for visual feedback + assignment
        } label: {
             HStack {
                Text(ocrString)
                Spacer()
                // Show temporary checkmark when selected
                if recentlySelected == ocrString {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            // Highlight background briefly on selection
            .background(recentlySelected == ocrString ? Color.green.opacity(0.3) : Color(uiColor: .systemGray6))
            .cornerRadius(5)
            // Apply subtle scale effect on selection
            .scaleEffect(recentlySelected == ocrString ? 1.03 : 1.0)
        }
        .buttonStyle(.plain) // Make it look like a list item
    }

    // MARK: - Helper Functions

    /// Handles visual selection feedback and triggers assignment callback after a delay.
    private func selectAndAssign(_ value: String?) {
        guard let actualValue = value else { return } // Needs a non-nil value to select

        recentlySelected = actualValue // Trigger animation state

        // Use asyncAfter to allow animation to show before calling back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onAssign(actualValue) // Callback to ViewModel
            // recentlySelected = nil // Optionally reset here or rely on view disappearing/updating
        }
    }

     /// Handles assignment for manual entry or skip, calling the parent callback immediately.
     private func assignValue(_ value: String?) {
         let valueToAssign = value?.trimmingCharacters(in: .whitespacesAndNewlines)

         // Don't assign if manual entry is empty (unless it's a skip)
         if value != nil && (valueToAssign?.isEmpty ?? true) {
              print("Manual entry is empty, not assigning.")
              return
         }

         onAssign(valueToAssign) // Callback to ViewModel (passes nil for skip)

         // Clear manual entry field if it was just assigned
         if value != nil {
              manualEntry = ""
         }
     }

     /// Helper to make dictionary keys more readable for display.
     private func userFriendlyFieldName(_ key: String) -> String {
         switch key {
             case "mfgDate": return "Mfg Date"
             case "voltage": return "Voltage"
             case "amps": return "Amps"
             case "pressure": return "Pressure"
             // Add other key->name mappings if needed
             default: return key.capitalized // Fallback
         }
     }

} // End struct

// MARK: - Preview
#Preview {
    FieldAssignmentView(
        isPresented: .constant(true),
        allOcrStrings: ["TITANAIR INDUSTRIES", "MODEL NO. TAC-4500X", "SERIAL NO. 8X9457-2034", "OTHER TEXT"],
        fieldName: "Model",
        onAssign: { value in print("Preview assigned: \(value ?? "nil")") },
        autoParsedData: ["voltage": "460 V", "amps": "32 A", "mfgDate": "2023-11", "pressure": "175 PSI"]
    )
}
