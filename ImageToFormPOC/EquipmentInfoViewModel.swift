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
import CoreML // Ensure CoreML is imported for MLModel types

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
    @Published var showOcrPreview = false
    @Published var isAssigningFields: Bool = false
    @Published var currentAssignmentIndex: Int = 0

    // MARK: - Data State
    @Published var ocrObservations: [RecognizedTextObservation] = []
    @Published var allOcrStrings: [String] = []
    @Published var fieldsToAssign: [AssignableField] = []
    @Published var assignedOcrValues = Set<String>()
    // Holds data parsed automatically before guided assignment
    @Published var initialAutoParsedData: [String: String] = [:]

    // MARK: - Actions from UI

    /// Clears state and triggers camera presentation.
    func initiateScan() {
        print("ViewModel: Initiating scan...")
        resetScanState(clearImage: true) // Clear everything including image
        showCamera = true
    }

    /// Handles image return from picker, starts OCR.
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
            // isProcessing is handled within performOCROnly or subsequent methods
        }
    }

    /// Processes OCR results after user proceeds from preview.
    func proceedWithOcrResults() {
        print("ViewModel: Proceeding with OCR results.")
        self.showOcrPreview = false
        self.isProcessing = true // Show indicator for parsing/assignment setup

        // Parse high-confidence data and get all raw lines
        let parseResult = self.parseHighConfidenceInfo(from: self.ocrObservations)
        let parsedData = parseResult.parsedData
        let rawLines = parseResult.allLines

        print("Initial Parsed Data: \(parsedData)")
        self.allOcrStrings = rawLines
        self.initialAutoParsedData = parsedData // Store auto-parsed data

        // Update form fields AND track initially assigned values
        updateFormFields(with: parsedData)
        var initialAssignedValues = Set<String>()
        if let val = parsedData["mfgDate"], !val.isEmpty { initialAssignedValues.insert(val) }
        if let val = parsedData["voltage"], !val.isEmpty { initialAssignedValues.insert(val) }
        if let val = parsedData["amps"], !val.isEmpty { initialAssignedValues.insert(val) }
        if let val = parsedData["pressure"], !val.isEmpty { initialAssignedValues.insert(val) }
        self.assignedOcrValues = initialAssignedValues // Initialize the set with auto-parsed values
        print("Form fields updated with auto-parsed data. Initial assigned values: \(initialAssignedValues)")

        // Determine Fields Still Needing Assignment
        var remainingFields: [AssignableField] = []
        if self.make.isEmpty { remainingFields.append(AssignableField(key: "make", name: "Make")) }
        if self.model.isEmpty { remainingFields.append(AssignableField(key: "model", name: "Model")) }
        if self.serialNumber.isEmpty { remainingFields.append(AssignableField(key: "serialNumber", name: "Serial Number")) }
        // Add other fields if needed

        print("Fields needing assignment: \(remainingFields.map { $0.name })")
        self.fieldsToAssign = remainingFields

        // Trigger Assignment UI ONLY if needed
        if !remainingFields.isEmpty {
            self.currentAssignmentIndex = 0
            self.isAssigningFields = true // Present the assignment sheet
            print("Triggering guided field assignment UI.")
        } else {
            print("No fields require manual assignment.")
            self.isAssigningFields = false
        }
        // Hide processing indicator now setup is done (unless assignment starts)
         if !self.isAssigningFields {
             self.isProcessing = false
         }
    }

    /// Resets state and triggers camera again from preview.
    func retakePhoto() {
        print("ViewModel: User requested retake.")
        resetScanState(clearImage: true) // Clear image and results
        showOcrPreview = false // Dismiss preview
        showCamera = true // Show camera again
    }

    /// Called by FieldAssignmentView when user assigns or skips a field.
    func handleAssignment(assignedValue: String?) {
        // Already on @MainActor because ViewModel is
        guard currentAssignmentIndex < fieldsToAssign.count else {
            print("ViewModel Error: Assignment index out of bounds.")
            finishAssignment()
            return
        }
        let currentField = fieldsToAssign[currentAssignmentIndex]
        let valueToAssign = assignedValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("ViewModel: Handling assignment for '\(currentField.name)': Value='\(valueToAssign)' (Skipped=\(assignedValue == nil))")

        // Update the correct @Published property
        switch currentField.key {
        case "make": self.make = valueToAssign
        case "model": self.model = valueToAssign
        case "serialNumber": self.serialNumber = valueToAssign
        default: print("ViewModel Warning: Unknown field key during assignment: \(currentField.key)")
        }

        // Track the assigned OCR value (if not skipped and not empty)
        // This prevents showing already used values in subsequent steps
        if assignedValue != nil && !valueToAssign.isEmpty {
             assignedOcrValues.insert(valueToAssign)
             print("ViewModel: Added '\(valueToAssign)' to assigned values. Current set: \(assignedOcrValues)")
        }

        // Move to the next field or finish
        currentAssignmentIndex += 1
        if currentAssignmentIndex >= fieldsToAssign.count {
            finishAssignment()
        } else {
            print("ViewModel: Moving to next field assignment: \(fieldsToAssign[currentAssignmentIndex].name)")
        }
    }

    /// Called when the assignment flow finishes or is cancelled.
     func finishAssignment() {
        print("ViewModel: Assignment flow finished or cancelled.")
        isAssigningFields = false // Dismiss the sheet
        isProcessing = false // Ensure indicator is off
    }


    // MARK: - Internal Helper Functions

    /// Resets ALL relevant state variables for a new scan. Made internal access.
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
        clearFormFields()
    }

    /// Clears all form field state variables. Marked private.
    private func clearFormFields() {
        make = ""; model = ""; serialNumber = ""; manufacturingDateString = ""
        voltageString = ""; ampsString = ""; pressureString = ""
        print("ViewModel: Form fields cleared.")
    }

    /// Performs ONLY the OCR request on the image. Updates state and triggers preview. Marked private.
    private func performOCROnly(on image: UIImage) async {
        // Function needs to be on MainActor because it updates @Published properties
        guard let cgImage = image.cgImage else {
            print("ViewModel Error: Failed to get CGImage.")
            isProcessing = false // Ensure indicator stops
            return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("ViewModel: Starting Vision Text Recognition (New API)...")

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        do {
            // Await the async Vision perform call
            let results: [RecognizedTextObservation] = try await textRequest.perform(on: cgImage, orientation: imageOrientation)
            // Code here runs *after* await completes, guaranteed on Main Actor
            print("ViewModel OCR success: Found \(results.count) observations.")
            self.ocrObservations = results
            if !results.isEmpty {
                 self.showOcrPreview = true // Trigger preview
                 // isProcessing remains true until user action on preview
            } else {
                 self.showOcrPreview = false // Skip preview if no text
                 isProcessing = false // Stop processing if no text found
            }

        } catch {
            // Error handling also runs on Main Actor
            print("ViewModel Error: Failed to perform Vision request: \(error.localizedDescription)")
            self.ocrObservations = []
            isProcessing = false // Stop processing on error
        }
        print("ViewModel: OCR function finished.")
        // isProcessing logic handled within branches or by proceed/retake actions
    }

    /// Parses only high-confidence patterns from OCR results. Made internal access.
    func parseHighConfidenceInfo(from observations: [RecognizedTextObservation]) -> (parsedData: [String: String], allLines: [String]) {
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


    /// Updates the form state variables based on initially parsed data. Marked private.
    private func updateFormFields(with parsedData: [String: String]) {
        if let val = parsedData["mfgDate"], !val.isEmpty { self.manufacturingDateString = val }
        if let val = parsedData["voltage"], !val.isEmpty { self.voltageString = val }
        if let val = parsedData["amps"], !val.isEmpty { self.ampsString = val }
        if let val = parsedData["pressure"], !val.isEmpty { self.pressureString = val }
    }

    /// Orientation Helper. Marked private as it's only used internally here.
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
