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
    let allOcrStrings: [String] // Filtered list (excluding already assigned by ViewModel)
    let fieldName: String
    let onAssign: (String?) -> Void

    // MARK: - Local State
    @State private var manualEntry: String = ""
    // --- RESTORED: State for selection animation ---
    @State private var recentlySelected: String? = nil
    // --- END RESTORE ---

    private let filterKeywords = ["weight", "model", "serial"]
    private let exactFilterValues = ["CE", "USA"]

    private var filteredOcrStrings: [String] {
        allOcrStrings.filter { ocrString in
            let lowercasedString = ocrString.lowercased()
            if exactFilterValues.contains(where: { $0.caseInsensitiveCompare(ocrString) == .orderedSame }) {
                return false
            }
            if filterKeywords.contains(where: { lowercasedString.contains($0) }) {
                return false
            }
            return true
        }
    }


    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 0) {

                // Header showing which field to assign
                VStack(alignment: .leading) {
                    Text("Assign Value For:")
                        .font(.headline).foregroundColor(.gray)
                    Text(fieldName)
                        .font(.title).fontWeight(.bold)
                }
                .padding(.horizontal).padding(.top).padding(.bottom, 10)

                Divider()

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
                        if filteredOcrStrings.isEmpty {
                             Text("No relevant OCR results available for assignment.")
                                 .foregroundColor(.gray)
                                 .padding()
                        } else {
                            ForEach(filteredOcrStrings, id: \.self) { ocrString in
                                // --- UPDATED: Use Button with restored animation logic ---
                                Button {
                                    // Call helper which handles animation and callback
                                    selectAndAssign(ocrString)
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
                                    .background(recentlySelected == ocrString ? Color.green.opacity(0.2) : Color(uiColor: .systemGray6))
                                    .cornerRadius(5)
                                     // Apply subtle scale effect on selection
                                    .scaleEffect(recentlySelected == ocrString ? 1.03 : 1.0)
                                }
                                .buttonStyle(.plain) // Make it look like a list item
                                // --- END UPDATE ---
                            }
                        }
                    }
                    .padding(.horizontal).padding(.bottom)
                }
                // --- RESTORED: Animation modifier ---
                .animation(.easeInOut(duration: 0.2), value: recentlySelected)
                // --- END RESTORE ---

                Divider().padding(.top, 5)

                // Skip button
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
                    Button("Cancel All") {
                        print("Cancelling assignment flow.")
                        isPresented = false
                    }
                }
            }
        } // End NavigationView
    } // End body

    // REMOVED: Subview Builder ocrStringButton is integrated into ForEach

    // --- RESTORED: Helper function for selection animation ---
    /// Handles visual selection feedback and triggers assignment callback after a delay.
    private func selectAndAssign(_ value: String?) {
        guard let actualValue = value else { return } // Needs a non-nil value to select

        recentlySelected = actualValue // Trigger animation state

        // Use asyncAfter to allow animation to show before calling back
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onAssign(actualValue) // Callback to ViewModel
            // Resetting recentlySelected here might cause flicker if view updates slowly.
            // It's often better to let it reset when the view disappears or the list changes.
            // recentlySelected = nil
        }
    }
    // --- END RESTORE ---

    // MARK: - Helper Functions
     /// Handles assignment for manual entry or skip, calling the parent callback immediately.
     private func assignValue(_ value: String?) {
         let valueToAssign = value?.trimmingCharacters(in: .whitespacesAndNewlines)

         if value != nil && (valueToAssign?.isEmpty ?? true) {
              print("Manual entry is empty, not assigning.")
              return
         }
         print("Assigning value: \(valueToAssign ?? "nil") (Skipped=\(value == nil))")
         onAssign(valueToAssign) // Callback to ViewModel

         if value != nil {
              manualEntry = ""
         }
     }

} // End struct

// MARK: - Preview
#Preview {
    FieldAssignmentView(
        isPresented: .constant(true),
        allOcrStrings: ["TITANAIR INDUSTRIES", "MODEL NO. TAC-4500X", "SERIAL NO. 8X9457-2034", "OTHER TEXT", "CE", "USA", "Net Weight 100kg", "2024-01"],
        fieldName: "Model",
        onAssign: { value in print("Preview assigned: \(value ?? "nil")") }
    )
}

