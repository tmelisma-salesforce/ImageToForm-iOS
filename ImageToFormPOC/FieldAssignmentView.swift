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
    let allOcrStrings: [String] // Filtered list
    let fieldName: String
    let onAssign: (String?) -> Void
    let autoParsedData: [String: String] // Auto-parsed data

    // MARK: - Local State
    @State private var manualEntry: String = ""
    @State private var recentlySelected: String? = nil

    // Helper for stable display order of auto-parsed data
    private var sortedAutoParsedKeys: [String] {
        autoParsedData.keys.sorted()
    }

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {

                // Header
                VStack(alignment: .leading) {
                    Text("Assign Value For:").font(.headline).foregroundColor(.gray)
                    Text(fieldName).font(.title).fontWeight(.bold)
                }
                .padding(.horizontal).padding(.top).padding(.bottom, 10)

                Divider()

                // Display Auto-Parsed Values
                 if !autoParsedData.isEmpty {
                     VStack(alignment: .leading) {
                         Text("Auto-Detected Values:").font(.caption).foregroundColor(.gray).padding(.bottom, 1)
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

                // Manual Entry
                HStack {
                    TextField("Enter Manually or Select Below", text: $manualEntry).textFieldStyle(.roundedBorder)
                    Button("Assign Manual") { assignValue(manualEntry) }.buttonStyle(.bordered).disabled(manualEntry.isEmpty)
                }
                .padding([.horizontal, .bottom]).padding(.top)

                // OCR Results List
                Text("Select from OCR Results:").font(.caption).padding(.horizontal).padding(.bottom, 5)
                ScrollView {
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(allOcrStrings, id: \.self) { ocrString in
                            ocrStringButton(ocrString)
                        }
                    }
                    .padding(.horizontal).padding(.bottom)
                }
                .animation(.easeInOut(duration: 0.2), value: recentlySelected)

                Divider().padding(.top, 5)

                // Skip Button
                HStack {
                    Spacer()
                    Button("Skip Field") { assignValue(nil) }
                    Spacer()
                }
                .padding()

            } // End main VStack
            .navigationTitle("Assign \(fieldName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel All") { isPresented = false } // Simply dismiss
                }
            }
        } // End NavigationView
    } // End body

    // MARK: - Subview Builder for List Buttons
    @ViewBuilder
    private func ocrStringButton(_ ocrString: String) -> some View {
        Button {
            selectAndAssign(ocrString)
        } label: {
             HStack {
                Text(ocrString)
                Spacer()
                if recentlySelected == ocrString {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(recentlySelected == ocrString ? Color.green.opacity(0.3) : Color(uiColor: .systemGray6))
            .cornerRadius(5)
            .scaleEffect(recentlySelected == ocrString ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helper Functions (Full Implementation)

    /// Handles visual selection feedback and triggers assignment callback after a delay.
    private func selectAndAssign(_ value: String?) {
        guard let actualValue = value else { return } // Require value
        // No local isAssigning state to check/set

        recentlySelected = actualValue // Trigger visual feedback

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onAssign(actualValue) // Call parent's assignment logic
            // Don't need to manage isAssigning or recentlySelected reset here, parent handles flow
        }
    }

     /// Handles assignment for manual entry or skip, calling the parent callback immediately.
     private func assignValue(_ value: String?) {
         let valueToAssign = value?.trimmingCharacters(in: .whitespacesAndNewlines)
         // Only assign non-empty manual entry, or nil for skip
         if valueToAssign?.isEmpty ?? false, value != nil {
              print("Manual entry is empty, not assigning.")
              return // Don't assign empty string from manual field
         }
         onAssign(valueToAssign) // Pass back trimmed manual value or nil for skip
     }

     /// Helper to make dictionary keys more readable
     private func userFriendlyFieldName(_ key: String) -> String {
         switch key {
             case "mfgDate": return "Mfg Date"
             case "voltage": return "Voltage"
             case "amps": return "Amps"
             case "pressure": return "Pressure"
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
