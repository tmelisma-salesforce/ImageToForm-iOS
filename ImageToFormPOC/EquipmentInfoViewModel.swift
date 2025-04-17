//
//  EquipmentInfoViewModel.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision
import CoreGraphics
import CoreML // Ensure CoreML is imported if Resnet50 class is used (even if commented out later)

// Represents a field needing assignment
struct AssignableField: Identifiable {
    let id = UUID()
    let key: String
    let name: String
}

// Main Actor ensures UI updates happen on the main thread
@MainActor
class EquipmentInfoViewModel: ObservableObject {

    // MARK: - Form Field State
    @Published var make: String = ""
    @Published var model: String = ""
    @Published var serialNumber: String = ""
    @Published var manufacturingDateString: String = ""
    @Published var voltageString: String = ""
    @Published var ampsString: String = ""
    @Published var pressureString: String = ""

    // MARK: - UI Control State
    @Published var showCamera = false
    @Published var capturedEquipmentImage: UIImage? = nil
    @Published var isProcessing = false
    @Published var showOcrPreview = false // Controls the OCR Preview sheet
    @Published var showAutoParseReview = false // Controls Auto-Parse Review Sheet
    @Published var isAssigningFields: Bool = false // Triggers the assignment sheet
    @Published var currentAssignmentIndex: Int = 0

    // MARK: - Data State
    @Published var ocrObservations: [RecognizedTextObservation] = [] // Holds results from Vision OCR
    @Published var allOcrStrings: [String] = [] // Holds all raw strings for assignment UI
    @Published var fieldsToAssign: [AssignableField] = [] // Holds fields needing manual assignment
    @Published var assignedOcrValues = Set<String>() // Tracks OCR strings used in assignment
    @Published var initialAutoParsedData: [String: String] = [:] // Holds values from initial parse


    // MARK: - Actions from UI

    /// Clears state and triggers camera presentation.
    func initiateScan() {
        print("ViewModel: Initiating scan...")
        resetScanState(clearImage: true)
        showCamera = true
    }

    /// Handles image return from picker binding's setter, starts OCR.
    func imageCaptured(_ image: UIImage?) {
        guard let capturedImage = image else {
            print("ViewModel: Image capture cancelled or failed.")
            return
        }
        print("ViewModel: Image captured. Storing image and starting OCR Task.")
        self.capturedEquipmentImage = capturedImage // Store the image
        Task { // Launch background task for Vision
            self.isProcessing = true // Show indicator
            await performOCROnly(on: capturedImage)
            // isProcessing state is handled within performOCROnly or subsequent methods
        }
    }

    /// Processes OCR results after user proceeds from OCR preview.
    /// Performs initial parse and triggers Auto-Parse Review.
    func proceedWithOcrResults() {
        print("ViewModel: Proceeding with OCR results.")
        self.showOcrPreview = false // Dismiss OCR Preview
        self.isProcessing = true // Show indicator for parsing step

        // Perform initial parse on the stored OCR observations
        let parseResult = self.parseHighConfidenceInfo(from: self.ocrObservations)
        let parsedData = parseResult.parsedData
        let rawLines = parseResult.allLines

        print("Initial Parsed Data: \(parsedData)")
        self.allOcrStrings = rawLines // Store all lines for potential assignment later
        self.initialAutoParsedData = parsedData // Store data for the review screen

        // Update the main form fields immediately with auto-parsed data
        updateFormFields(with: parsedData)
        var initialAssignedValues = Set<String>()
        // Populate the set of values considered "used" by auto-parsing
        if let val = parsedData["mfgDate"], !val.isEmpty { initialAssignedValues.insert(val) }
        if let val = parsedData["voltage"], !val.isEmpty { initialAssignedValues.insert(val) }
        if let val = parsedData["amps"], !val.isEmpty { initialAssignedValues.insert(val) }
        if let val = parsedData["pressure"], !val.isEmpty { initialAssignedValues.insert(val) }
        self.assignedOcrValues = initialAssignedValues // Initialize the set
        print("Form fields updated with auto-parsed data. Initial assigned values: \(initialAssignedValues)")

        // Trigger Auto-Parse Review Sheet
        self.showAutoParseReview = true
        self.isProcessing = false // Hide indicator while user reviews
        print("Triggering Auto-Parse Review UI.")
    }

     /// Called when user accepts the auto-parsed values from AutoParseReviewView.
     /// Determines remaining fields and triggers assignment flow if needed.
    func acceptAutoParseAndProceedToAssignment() {
        print("ViewModel: Auto-parsed results accepted. Determining remaining fields...")
        self.showAutoParseReview = false // Dismiss the review sheet
        // isProcessing indicator can remain off, assignment is interactive

        // Determine Fields Still Needing Assignment (based on current form state)
        var remainingFields: [AssignableField] = []
        if self.make.isEmpty { remainingFields.append(AssignableField(key: "make", name: "Make")) }
        if self.model.isEmpty { remainingFields.append(AssignableField(key: "model", name: "Model")) }
        if self.serialNumber.isEmpty { remainingFields.append(AssignableField(key: "serialNumber", name: "Serial Number")) }
        // Add checks for other fields here if their auto-parse was unreliable
        // e.g., if manufacturingDateString.isEmpty { remainingFields.append(...) }

        print("Fields needing assignment: \(remainingFields.map { $0.name })")
        self.fieldsToAssign = remainingFields

        // Trigger Assignment UI ONLY if needed
        if !remainingFields.isEmpty {
            self.currentAssignmentIndex = 0
            self.isAssigningFields = true // Present the assignment sheet
            print("Triggering guided field assignment UI.")
        } else {
            print("No fields require manual assignment. Process complete.")
            self.isAssigningFields = false
            // isProcessing remains false
        }
    }


    /// Resets state and triggers camera again from OCR preview.
    func retakePhoto() {
        print("ViewModel: User requested retake.")
        resetScanState(clearImage: true) // Clear image and results
        showOcrPreview = false // Dismiss preview
        showCamera = true // Show camera again
    }

    /// Called by FieldAssignmentView when user assigns or skips a field.
    func handleAssignment(assignedValue: String?) {
        // Ensure execution on MainActor (already guaranteed by class)
        guard currentAssignmentIndex < fieldsToAssign.count else {
            print("ViewModel Error: Assignment index out of bounds.")
            finishAssignment()
            return
        }
        let currentField = fieldsToAssign[currentAssignmentIndex]
        // Get assigned value (trimmed) or empty string if skipped/nil
        let valueToAssign = assignedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("ViewModel: Handling assignment for '\(currentField.name)': Value='\(valueToAssign)' (Skipped=\(assignedValue == nil))")

        // Update the correct @Published property based on field key
        switch currentField.key {
        case "make": self.make = valueToAssign
        case "model": self.model = valueToAssign
        case "serialNumber": self.serialNumber = valueToAssign
        default: print("ViewModel Warning: Unknown field key during assignment: \(currentField.key)")
        }

        // Track the assigned OCR value (if not skipped and not empty)
        // This prevents showing already used values in subsequent assignment steps
        if assignedValue != nil && !valueToAssign.isEmpty {
             assignedOcrValues.insert(valueToAssign)
             print("ViewModel: Added '\(valueToAssign)' to assigned values. Current set: \(assignedOcrValues)")
        }

        // Move to the next field or finish assignment flow
        currentAssignmentIndex += 1
        if currentAssignmentIndex >= fieldsToAssign.count {
            finishAssignment()
        } else {
            print("ViewModel: Moving to next field assignment: \(fieldsToAssign[currentAssignmentIndex].name)")
            // The assignment sheet (@State isAssigningFields) remains presented,
            // its content will update because its inputs (fieldName, filtered list) change.
        }
    }

    /// Called when the assignment flow finishes (all fields done) or is cancelled.
     func finishAssignment() {
        print("ViewModel: Assignment flow finished or cancelled.")
        isAssigningFields = false // Dismiss the assignment sheet
        isProcessing = false // Ensure processing indicator is definitely off
    }


    // MARK: - Internal Helper Functions

    /// Resets ALL relevant state variables for a new scan. Internal access (default).
    func resetScanState(clearImage: Bool) {
        print("ViewModel: Resetting state (clearImage: \(clearImage)).")
        if clearImage { self.capturedEquipmentImage = nil }
        self.ocrObservations = []
        self.allOcrStrings = []
        self.fieldsToAssign = []
        self.currentAssignmentIndex = 0
        self.isAssigningFields = false
        self.isProcessing = false
        self.assignedOcrValues = Set<String>()
        self.initialAutoParsedData = [:] // Clear auto-parsed cache
        self.showOcrPreview = false // Ensure preview sheet state is reset
        self.showAutoParseReview = false // Ensure auto-parse review state is reset
        clearFormFields()
    }

    /// Clears all form field state variables. Marked private.
    private func clearFormFields() {
        make = ""; model = ""; serialNumber = ""; manufacturingDateString = ""
        voltageString = ""; ampsString = ""; pressureString = ""
        print("ViewModel: Form fields cleared.")
    }

    /// Performs ONLY the OCR request on the image using new Swift API. Updates state and triggers preview. Marked private.
    private func performOCROnly(on image: UIImage) async {
        // Ensure execution on MainActor
        guard let cgImage = image.cgImage else {
            print("ViewModel Error: Failed to get CGImage.")
            isProcessing = false // Stop processing on early exit
            return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("ViewModel: Starting Vision Text Recognition (New API)...")

        // Create and configure the text recognition request struct
        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        do {
            // Perform the request using async/await directly on the request struct
            let results: [RecognizedTextObservation] = try await textRequest.perform(on: cgImage, orientation: imageOrientation)
            // Code after await is guaranteed on MainActor due to func signature

            print("ViewModel OCR success: Found \(results.count) observations.")
            self.ocrObservations = results // Store the results

            // Trigger the OCR Preview sheet ONLY if text was actually found
            if !results.isEmpty {
                 self.showOcrPreview = true
                 // isProcessing remains true - user must Proceed or Retake from preview
            } else {
                 print("ViewModel: No text found by OCR, skipping preview.")
                 self.showOcrPreview = false
                 isProcessing = false // Stop processing if no text found
            }

        } catch {
            // Handle errors during OCR performance
            print("ViewModel Error: Failed to perform Vision request: \(error.localizedDescription)")
            self.ocrObservations = []
            isProcessing = false // Stop processing on error
            // Consider showing an error alert to the user here
        }
        print("ViewModel: OCR function finished.")
    }

    /// Parses only high-confidence patterns (Date, V, A, PSI) from OCR results. Internal access.
    func parseHighConfidenceInfo(from observations: [RecognizedTextObservation]) -> (parsedData: [String: String], allLines: [String]) {
        var parsedData: [String: String] = [:]
        // Extract clean, non-empty lines from observations
        let allTextLines = observations.compactMap {
            $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty }

        print("--- Raw OCR Lines for Parsing (High Confidence Pass) ---")
        allTextLines.forEach { print($0) }
        print("--------------------------------------------------------")

        // Apply specific regex patterns to find high-confidence values
        for line in allTextLines {
            // Pressure (e.g., "175 PSI", "150psi")
            if parsedData["pressure"] == nil,
               let match = line.range(of: #"(\d+(\.\d+)?\s?PSI)"#, options: [.regularExpression, .caseInsensitive]) {
                 let value = String(line[match]).trimmingCharacters(in: .whitespaces)
                 // Basic check to ensure we captured digits
                 if value.rangeOfCharacter(from: .decimalDigits) != nil {
                      parsedData["pressure"] = value
                      print("Regex found Pressure: \(value)")
                 }
            }
            // Voltage (e.g., "460 V", "120VAC", "240V")
            if parsedData["voltage"] == nil,
               let match = line.range(of: #"(\d+(\.\d+)?\s?V(AC|DC)?)"#, options: [.regularExpression, .caseInsensitive]),
               String(line[match]).rangeOfCharacter(from: .decimalDigits) != nil {
                 let value = String(line[match]).trimmingCharacters(in: .whitespaces)
                 parsedData["voltage"] = value
                 print("Regex found Voltage: \(value)")
            }
             // Amps (e.g., "32 A", "15Amps")
             if parsedData["amps"] == nil,
                let match = line.range(of: #"(\d+(\.\d+)?\s?A(mps)?)"#, options: [.regularExpression, .caseInsensitive]),
                 String(line[match]).rangeOfCharacter(from: .decimalDigits) != nil {
                  let value = String(line[match]).trimmingCharacters(in: .whitespaces)
                  parsedData["amps"] = value
                  print("Regex found Amps: \(value)")
             }
             // Date (YYYY-MM or YYYY/MM, anchored to line start/end for confidence)
              if parsedData["mfgDate"] == nil,
                 let match = line.trimmingCharacters(in: .whitespaces).range(of: #"^\d{4}[-/]\d{1,2}$"#, options: .regularExpression) {
                   let value = String(line.trimmingCharacters(in: .whitespaces)[match])
                   parsedData["mfgDate"] = value
                   print("Regex found Date: \(value)")
              }
        }
        // Return dictionary of parsed values and the complete list of raw lines
        return (parsedData, allTextLines)
    }

    /// Updates the main form's @State variables based on initially parsed data. Marked private.
    private func updateFormFields(with parsedData: [String: String]) {
        // Only update fields targeted by the high-confidence parser
        if let val = parsedData["mfgDate"], !val.isEmpty { self.manufacturingDateString = val }
        if let val = parsedData["voltage"], !val.isEmpty { self.voltageString = val }
        if let val = parsedData["amps"], !val.isEmpty { self.ampsString = val }
        if let val = parsedData["pressure"], !val.isEmpty { self.pressureString = val }
    }

    /// Orientation Helper. Marked private.
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
} // End ViewModel
