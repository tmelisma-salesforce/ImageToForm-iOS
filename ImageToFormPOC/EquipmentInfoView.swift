//
//  EquipmentInfoView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25. // Verify/update date if needed
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Vision framework for OCR and Observations
import CoreGraphics // For orientation types

// Ensure Deployment Target is iOS 18.0+ for the new Vision APIs used

// Represents a field that might need manual assignment
struct AssignableField: Identifiable {
    let id = UUID()
    let key: String // Internal key (matches @State variable name)
    let name: String // User-friendly display name
}

struct EquipmentInfoView: View {

    // MARK: - State Variables for Form Fields
    @State private var make: String = ""
    @State private var model: String = ""
    @State private var serialNumber: String = ""
    @State private var manufacturingDateString: String = ""
    @State private var voltageString: String = ""
    @State private var ampsString: String = ""
    @State private var pressureString: String = ""

    // MARK: - State Variables for Image Capture & Processing
    @State private var showCamera = false
    @State private var capturedEquipmentImage: UIImage? = nil
    @State private var isProcessing = false
    // Keep raw results for the debug display section
    @State private var equipmentOcrResultsForDebug: [RecognizedTextObservation] = []

    // MARK: - State Variables for Guided Assignment Flow
    @State private var isAssigningFields: Bool = false // Triggers the assignment sheet
    @State private var allOcrStrings: [String] = [] // List shown in assignment UI
    @State private var fieldsToAssign: [AssignableField] = [] // Fields needing assignment
    @State private var currentAssignmentIndex: Int = 0 // Current field index
    @State private var assignedOcrValues = Set<String>() // Track used OCR values

    // MARK: - Body Definition
    var body: some View {
        // ScrollView ensures content fits on smaller screens
        ScrollView {
            // Main vertical stack for all content
            VStack(alignment: .leading, spacing: 15) {

                // --- Equipment Details Form ---
                // Contains TextFields bound to the @State variables
                Form {
                    Section("Equipment Details") {
                        TextField("Make", text: $make)
                        TextField("Model", text: $model)
                        TextField("Serial Number", text: $serialNumber)
                            .keyboardType(.asciiCapable)
                            .autocapitalization(.allCharacters)
                        TextField("Manufacturing Date (YYYY-MM)", text: $manufacturingDateString)
                            .keyboardType(.numbersAndPunctuation)
                    }
                    Section("Specifications") {
                        TextField("Voltage (e.g., 460V)", text: $voltageString)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Amps (e.g., 32A)", text: $ampsString)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("Pressure (e.g., 175PSI)", text: $pressureString)
                            .keyboardType(.numbersAndPunctuation)
                    }
                }
                .frame(height: calculateFormHeight()) // Give form a calculated height
                .padding(.bottom)
                // Disable form during processing or assignment
                .disabled(isProcessing || isAssigningFields)

                // --- Image Capture Section ---
                Text("Equipment Label Photo:")
                    .font(.headline)
                    .padding(.horizontal)

                // Display captured image or placeholder
                if let image = capturedEquipmentImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .padding(.horizontal)
                        .overlay(alignment: .topTrailing) {
                            // Button to clear image and reset state
                            Button {
                                resetScan() // Use helper to reset all state
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .background(Color.white.opacity(0.8))
                                    .clipShape(Circle())
                                    .padding(5)
                            }
                        }
                } else {
                    // Placeholder if no image captured
                    Text("No photo captured yet.")
                        .foregroundColor(.gray)
                        .frame(height: 100)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color(uiColor: .systemGray6)))
                        .padding(.horizontal)
                }

                // --- Scan Button ---
                // This button triggers the camera/photo library
                Button {
                    resetScan() // Clear everything before starting a new scan
                    showCamera = true // Present the ImagePicker sheet/cover
                } label: {
                    Label(capturedEquipmentImage == nil ? "Scan Equipment Label" : "Rescan Equipment Label",
                          systemImage: "camera.fill")
                }
                .buttonStyle(.bordered)
                .padding([.horizontal, .top])
                // Disable button while processing or assigning fields
                .disabled(isProcessing || isAssigningFields)

                // --- Debug Section (Optional) ---
                DisclosureGroup("Raw OCR Results (Debug)") {
                    if isProcessing {
                        ProgressView()
                    } else if equipmentOcrResultsForDebug.isEmpty {
                        Text(capturedEquipmentImage == nil ? "Scan an image." : "No text detected.")
                            .foregroundColor(.gray)
                            .font(.caption)
                    } else {
                        VStack(alignment: .leading) {
                            ForEach(equipmentOcrResultsForDebug, id: \.uuid) { obs in
                                Text(obs.topCandidates(1).first?.string ?? "??")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()
                // --- End Debug Section ---

                Spacer() // Pushes content towards top

            } // End main VStack
        } // End ScrollView
        .navigationTitle("Capture Equipment Info") // Set screen title
        // --- Sheet for Field Assignment UI ---
        // Presented when isAssigningFields is true
        .sheet(isPresented: $isAssigningFields) {
             // Ensure we have a field to assign
             if currentAssignmentIndex < fieldsToAssign.count {
                 let currentField = fieldsToAssign[currentAssignmentIndex]
                 // Filter out already assigned OCR values before passing to sheet
                 let availableOcrStrings = allOcrStrings.filter { !assignedOcrValues.contains($0) }

                 // Present the FieldAssignmentView (ensure this file exists)
                 FieldAssignmentView(
                     isPresented: $isAssigningFields,
                     allOcrStrings: availableOcrStrings,
                     fieldName: currentField.name,
                     onAssign: handleAssignment // Callback function
                 )
             } else {
                  // Fallback if state is inconsistent
                  Text("Error: Inconsistent assignment state.")
                  Button("Dismiss") { isAssigningFields = false; isProcessing = false }
                      .padding()
             }
        }
        // --- Full Screen Cover for Camera ---
        // Presented when showCamera is true
        .fullScreenCover(isPresented: $showCamera) {
            ImagePicker(selectedImage: $capturedEquipmentImage) // Ensure ImagePicker.swift exists
        }
        // --- onChange Modifier to Trigger Processing ---
        // Runs when capturedEquipmentImage receives a new value
        .onChange(of: capturedEquipmentImage) { _, newImage in
            if let image = newImage {
                print("EquipmentInfoView: onChange detected new image. Launching processing Task.")
                // Start async task for Vision processing
                Task {
                    // Set processing state ON (on MainActor)
                    await MainActor.run { isProcessing = true }
                    // Perform OCR and initial parsing
                    await performVisionRequestAndParse(on: image)
                    // isProcessing state is handled within performVisionRequestAndParse
                    // or handleAssignment depending on whether assignment starts.
                }
            } else {
                // Handles case where image is set to nil (e.g., by resetScan)
                print("EquipmentInfoView: onChange detected image became nil.")
                // Clear results if image is removed
                Task { await MainActor.run { equipmentOcrResultsForDebug = [] } }
            }
        }
        // --- Overlay for Processing Indicator ---
        // Shows spinner when isProcessing is true
        .overlay {
            if isProcessing {
                ProcessingIndicatorView() // Ensure ProcessingIndicatorView.swift exists
            }
        }

    } // End body

    // MARK: - Helper Functions

    /// Calculates an estimated height for the form.
    private func calculateFormHeight() -> CGFloat {
        let rowCount = 7 // Number of TextFields in the form
        let rowHeightEstimate: CGFloat = 55 // Estimated height per row
        return CGFloat(rowCount) * rowHeightEstimate
    }

    /// Clears all form field @State variables.
    @MainActor private func clearFormFields() {
        make = ""; model = ""; serialNumber = ""; manufacturingDateString = ""
        voltageString = ""; ampsString = ""; pressureString = ""
        print("Form fields cleared.")
    }

     /// Resets all relevant state variables for a new scan attempt.
    @MainActor
    private func resetScan() {
        print("Resetting scan state.")
        self.capturedEquipmentImage = nil
        self.equipmentOcrResultsForDebug = []
        self.allOcrStrings = []
        self.fieldsToAssign = []
        self.currentAssignmentIndex = 0
        self.isAssigningFields = false
        self.isProcessing = false // Make sure indicator stops
        self.assignedOcrValues = Set<String>() // Clear the set of used values
        clearFormFields() // Also clear the form text fields
    }


    // MARK: - Vision Processing & Parsing Function

    /// Performs OCR, attempts high-confidence parsing, and triggers assignment flow if needed.
    @MainActor
    private func performVisionRequestAndParse(on image: UIImage) async {
        // Set isProcessing true at the start of the actual work
        // isProcessing = true // Already set by the calling Task

        guard let cgImage = image.cgImage else {
            print("EquipmentInfoView Error: Failed to get CGImage.")
            isProcessing = false // Stop processing on early exit
            return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("EquipmentInfoView: Starting Vision Text Recognition (New API)...")

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        // Local variables for results
        var ocrObservations: [RecognizedTextObservation] = []
        var parsedData: [String: String] = [:]
        var rawLines: [String] = []
        var initialAssignedValues = Set<String>()
        var needsAssignment = false // Track if assignment UI should be shown

        do {
            // Perform OCR
            ocrObservations = try await textRequest.perform(on: cgImage, orientation: imageOrientation)
            print("EquipmentInfoView OCR success: Found \(ocrObservations.count) observations.")
            self.equipmentOcrResultsForDebug = ocrObservations // Update debug display state

            if !ocrObservations.isEmpty {
                // Perform Initial Parsing for high-confidence fields
                print("Performing initial parsing...")
                let parseResult = self.parseHighConfidenceInfo(from: ocrObservations)
                parsedData = parseResult.parsedData
                rawLines = parseResult.allLines // Get all raw lines for assignment UI
                print("Initial Parsed Data: \(parsedData)")
                self.allOcrStrings = rawLines

                // Update Form Fields with Auto-Parsed Data & Track Assigned Values
                updateFormFields(with: parsedData) // Update state for Date, V, A, PSI
                if let val = parsedData["mfgDate"], !val.isEmpty { initialAssignedValues.insert(val) }
                if let val = parsedData["voltage"], !val.isEmpty { initialAssignedValues.insert(val) }
                if let val = parsedData["amps"], !val.isEmpty { initialAssignedValues.insert(val) }
                if let val = parsedData["pressure"], !val.isEmpty { initialAssignedValues.insert(val) }
                self.assignedOcrValues = initialAssignedValues // Initialize the set
                print("Form fields updated with auto-parsed data. Initial assigned values: \(initialAssignedValues)")

                // Determine Fields Still Needing Assignment
                var remainingFields: [AssignableField] = []
                if self.make.isEmpty { remainingFields.append(AssignableField(key: "make", name: "Make")) }
                if self.model.isEmpty { remainingFields.append(AssignableField(key: "model", name: "Model")) }
                if self.serialNumber.isEmpty { remainingFields.append(AssignableField(key: "serialNumber", name: "Serial Number")) }
                // Add checks for date/voltage/etc. here if their parsing is unreliable
                // and you want the user to confirm/assign them too.

                print("Fields needing assignment: \(remainingFields.map { $0.name })")
                self.fieldsToAssign = remainingFields

                // Trigger Assignment UI ONLY if needed
                if !remainingFields.isEmpty {
                    self.currentAssignmentIndex = 0
                    self.isAssigningFields = true // This will present the sheet
                    needsAssignment = true
                    print("Triggering guided field assignment UI.")
                    // isProcessing will be set to false by handleAssignment when flow completes
                } else {
                    print("No fields require manual assignment.")
                }

            } else {
                // No OCR results found
                self.allOcrStrings = []
                self.fieldsToAssign = []
            }

        } catch {
            // Handle errors during OCR
            print("EquipmentInfoView Error: Failed to perform Vision request: \(error.localizedDescription)")
            self.equipmentOcrResultsForDebug = []
            self.allOcrStrings = []
            self.fieldsToAssign = []
            // clearFormFields()
        }

        // Set Processing to false ONLY if assignment wasn't triggered
        if !needsAssignment {
            print("Setting isProcessing = false (no assignment needed or error).")
            isProcessing = false
        }
        print("EquipmentInfoView: Vision processing & initial parsing function finished.")

    } // End performVisionRequestAndParse


    // MARK: - Parsing Logic (High-Confidence Patterns Only)
    /// Attempts to parse only high-confidence patterns (Date, V, A, PSI).
    /// Returns both the parsed data and all raw text lines.
    private func parseHighConfidenceInfo(from observations: [RecognizedTextObservation]) -> (parsedData: [String: String], allLines: [String]) {
        var parsedData: [String: String] = [:]
        // Extract clean lines, removing empty ones
        let allTextLines = observations.compactMap {
            $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        print("--- Raw OCR Lines for Parsing (High Confidence Pass) ---")
        allTextLines.forEach { print($0) }
        print("--------------------------------------------------------")

        // Simple Regex approach for high-confidence patterns
        for line in allTextLines {
            // Pressure (Number followed by PSI)
            if parsedData["pressure"] == nil,
               let match = line.range(of: #"(\d+(\.\d+)?\s?PSI)"#, options: [.regularExpression, .caseInsensitive]) {
                 let value = String(line[match]).trimmingCharacters(in: .whitespaces)
                 if value.rangeOfCharacter(from: .decimalDigits) != nil {
                      parsedData["pressure"] = value
                      print("Regex found Pressure: \(value)")
                 }
            }
            // Voltage (Number followed by V/VAC/VDC)
            if parsedData["voltage"] == nil,
               let match = line.range(of: #"(\d+(\.\d+)?\s?V(AC|DC)?)"#, options: [.regularExpression, .caseInsensitive]),
               String(line[match]).rangeOfCharacter(from: .decimalDigits) != nil {
                 let value = String(line[match]).trimmingCharacters(in: .whitespaces)
                 parsedData["voltage"] = value
                 print("Regex found Voltage: \(value)")
            }
             // Amps (Number followed by A/Amps)
             if parsedData["amps"] == nil,
                let match = line.range(of: #"(\d+(\.\d+)?\s?A(mps)?)"#, options: [.regularExpression, .caseInsensitive]),
                 String(line[match]).rangeOfCharacter(from: .decimalDigits) != nil {
                  let value = String(line[match]).trimmingCharacters(in: .whitespaces)
                  parsedData["amps"] = value
                  print("Regex found Amps: \(value)")
             }
             // Date (YYYY-MM or YYYY/MM format, anchored)
              if parsedData["mfgDate"] == nil,
                 let match = line.trimmingCharacters(in: .whitespaces).range(of: #"^\d{4}[-/]\d{1,2}$"#, options: .regularExpression) {
                   let value = String(line.trimmingCharacters(in: .whitespaces)[match])
                   parsedData["mfgDate"] = value
                   print("Regex found Date: \(value)")
              }
        }
        // Keyword logic explicitly removed for this simplified parser

        return (parsedData, allTextLines) // Return parsed data and ALL raw lines
    }

    /// Updates the form's @State variables based on initially parsed data.
    @MainActor private func updateFormFields(with parsedData: [String: String]) {
        if let val = parsedData["mfgDate"], !val.isEmpty { self.manufacturingDateString = val }
        if let val = parsedData["voltage"], !val.isEmpty { self.voltageString = val }
        if let val = parsedData["amps"], !val.isEmpty { self.ampsString = val }
        if let val = parsedData["pressure"], !val.isEmpty { self.pressureString = val }
    }


    // MARK: - Assignment Handling

    /// Called by FieldAssignmentView when user assigns or skips a field.
    @MainActor
    private func handleAssignment(assignedValue: String?) {
        guard currentAssignmentIndex < fieldsToAssign.count else {
            print("Error: Assignment index out of bounds.")
            isAssigningFields = false
            isProcessing = false // Ensure processing stops
            return
        }

        let currentField = fieldsToAssign[currentAssignmentIndex]
        let valueToAssign = assignedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        print("Handling assignment for '\(currentField.name)': Value='\(valueToAssign)' (Skipped=\(assignedValue == nil))")

        // Update the correct @State variable based on the field key
        switch currentField.key {
        case "make": self.make = valueToAssign
        case "model": self.model = valueToAssign
        case "serialNumber": self.serialNumber = valueToAssign
        default: print("Warning: Unknown field key during assignment: \(currentField.key)")
        }

        // Track the assigned OCR value (if not skipped) to prevent re-displaying it
        if let ocrValue = assignedValue, !valueToAssign.isEmpty {
             assignedOcrValues.insert(valueToAssign)
             print("Added '\(valueToAssign)' to assigned values. Current set: \(assignedOcrValues)")
        }

        // Move to the next field or finish
        currentAssignmentIndex += 1
        if currentAssignmentIndex >= fieldsToAssign.count {
            print("Assignment complete.")
            isAssigningFields = false // Dismiss the sheet
            isProcessing = false // Ensure processing stops now
        } else {
            print("Moving to next field assignment: \(fieldsToAssign[currentAssignmentIndex].name)")
            // The sheet will update because FieldAssignmentView depends on state
            // that changes (index implies different fieldName, list is filtered)
        }
    }


    // --- Orientation Helper (Full Implementation) ---
    /// Converts UIImage.Orientation to the corresponding CGImagePropertyOrientation.
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up
            case .down: return .down
            case .left: return .left
            case .right: return .right
            case .upMirrored: return .upMirrored
            case .downMirrored: return .downMirrored
            case .leftMirrored: return .leftMirrored
            case .rightMirrored: return .rightMirrored
            @unknown default:
                print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up")
                return .up
         }
    }

} // End EquipmentInfoView

// MARK: - Preview
#Preview {
    NavigationView {
        EquipmentInfoView()
    }
}
