//
//  EquipmentInfoViewModel.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Needed for RecognizeTextRequest, RecognizedTextObservation
import CoreGraphics

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
    @Published var manufacturingDateString: String = "" // Stores YYYY-MM
    @Published var voltageString: String = ""
    @Published var ampsString: String = ""
    @Published var pressureString: String = ""

    // MARK: - UI Control State
    @Published var showCamera = false
    @Published var capturedEquipmentImage: UIImage? = nil // Still needed for processing
    @Published var isProcessing = false
    @Published var showOcrPreview = false // Controls the OCR Preview sheet
    @Published var showAutoParseReview = false // Controls Auto-Parse Review Sheet
    @Published var isAssigningFields: Bool = false // Triggers the assignment sheet
    @Published var currentAssignmentIndex: Int = 0
    @Published var showManualView: Bool = false   // Controls manual sheet presentation (if needed later)
    @Published var assignmentFlowComplete: Bool = false // Tracks if assignment/confirmation is done
    @Published var showConfirmationDestination: Bool = false // Controls navigation after confirm

    // MARK: - Data State
    @Published var ocrObservations: [RecognizedTextObservation] = []
    @Published var allOcrStrings: [String] = [] // All detected lines
    @Published var fieldsToAssign: [AssignableField] = [] // Fields needing manual assignment
    @Published var assignedOcrValues = Set<String>() // Tracks OCR strings already used
    @Published var initialAutoParsedData: [String: String] = [:] // Data found by initial regex/keyword pass


    // MARK: - Actions from UI

    /// Clears state and triggers camera presentation.
    func initiateScan() {
        print("ViewModel: initiateScan called.")
        resetScanState(clearImage: true) // Reset state, including assignmentFlowComplete
        showCamera = true
        print("ViewModel: showCamera set to true.")
    }

    /// Handles image return from picker binding's setter, starts OCR.
    func imageCaptured(_ image: UIImage?) {
        guard let capturedImage = image else {
            print("ViewModel: imageCaptured called with nil image.")
            return
        }
        print("ViewModel: imageCaptured called with valid image.")
        self.capturedEquipmentImage = capturedImage // Store image for processing
        Task {
            await MainActor.run {
                print("ViewModel: Starting OCR Task. Setting isProcessing=true.")
                self.isProcessing = true
                // assignmentFlowComplete is reset by initiateScan->resetScanState
            }
            await performOCROnly(on: capturedImage)
        }
    }

    /// Processes OCR results after user proceeds from OCR preview.
    /// Performs initial parse and triggers Auto-Parse Review.
    func proceedWithOcrResults() {
        print("ViewModel: proceedWithOcrResults called.")
        self.showOcrPreview = false
        self.isProcessing = true

        // 1. Perform initial high-confidence parse (Date, V, A, PSI)
        let parseResult = self.parseHighConfidenceInfo(from: self.ocrObservations)
        var parsedData = parseResult.parsedData // Make mutable
        let rawLines = parseResult.allLines

        print("Initial High-Confidence Parsed Data: \(parsedData)")
        self.allOcrStrings = rawLines // Store all lines for potential assignment later

        // Track values used by high-confidence parsing
        var currentAssignedValues = Set<String>()
        // Use the actual parsed value for tracking uniqueness
        if let val = parsedData["mfgDate"], !val.isEmpty { currentAssignedValues.insert(val) }
        if let val = parsedData["voltage"], !val.isEmpty { currentAssignedValues.insert(val) }
        if let val = parsedData["amps"], !val.isEmpty { currentAssignedValues.insert(val) }
        if let val = parsedData["pressure"], !val.isEmpty { currentAssignedValues.insert(val) }

        // 2. Attempt to auto-assign Model
        // Check if model is empty *and* not already found by regex (unlikely but safe)
        if self.model.isEmpty && parsedData["model"] == nil {
            if let modelValue = findValueAfterKeyword(keyword: "model", in: rawLines, excluding: currentAssignedValues) {
                print("Auto-assigning Model: \(modelValue)")
                // Don't directly set self.model yet, let updateFormFields handle it
                parsedData["model"] = modelValue // Add to parsed data for review/consistency
                currentAssignedValues.insert(modelValue)
            }
        }

        // 3. Attempt to auto-assign Serial Number
        // Check if serial is empty *and* not already found by regex (important due to date conflict)
        if self.serialNumber.isEmpty && parsedData["serialNumber"] == nil {
             if let serialValue = findValueAfterKeyword(keyword: "serial", in: rawLines, excluding: currentAssignedValues) {
                 print("Auto-assigning Serial: \(serialValue)")
                 // Don't directly set self.serialNumber yet
                 parsedData["serialNumber"] = serialValue // Add to parsed data

                 // --- Conflict Resolution: If Serial was wrongly parsed as Date, remove the incorrect date ---
                 if parsedData["mfgDate"] == serialValue {
                      print("Correcting conflict: Serial number was initially misidentified as Mfg Date. Removing incorrect date.")
                      parsedData.removeValue(forKey: "mfgDate")
                      // Remove the serial number from the 'date' entry in the used set if it was added
                      currentAssignedValues.remove(serialValue) // Re-inserting below is fine
                 }
                 // Ensure the correct serial value is tracked
                 currentAssignedValues.insert(serialValue)
                 // --- End Conflict Resolution ---
             }
         }


        // 4. Store final initially parsed data and assigned values
        self.initialAutoParsedData = parsedData
        self.assignedOcrValues = currentAssignedValues // Update the set of used values

        // 5. Update the main form fields immediately with ALL auto-parsed data
        // This ensures keyword results overwrite potentially incorrect regex results
        updateFormFields(with: parsedData)
        print("Form fields updated with auto-parsed data. Current assigned values: \(currentAssignedValues)")

        // 6. Trigger Auto-Parse Review Sheet
        print("ViewModel: Setting showAutoParseReview = true.")
        self.showAutoParseReview = true
        self.isProcessing = false
        print("Triggering Auto-Parse Review UI.")
    }

     /// Called when user accepts the auto-parsed values from AutoParseReviewView.
     /// Determines remaining fields and triggers assignment flow if needed.
    func acceptAutoParseAndProceedToAssignment() {
        print("ViewModel: acceptAutoParseAndProceedToAssignment called.")
        self.showAutoParseReview = false // Dismiss the review sheet

        // Determine Fields Still Needing Assignment (based on current form state)
        var remainingFields: [AssignableField] = []
        if self.make.isEmpty { remainingFields.append(AssignableField(key: "make", name: "Make")) }
        if self.model.isEmpty { remainingFields.append(AssignableField(key: "model", name: "Model")) }
        if self.serialNumber.isEmpty { remainingFields.append(AssignableField(key: "serialNumber", name: "Serial Number")) }
        if self.manufacturingDateString.isEmpty { remainingFields.append(AssignableField(key: "manufacturingDateString", name: "Manufacturing Date")) }
        // Add others if needed

        print("Fields needing assignment: \(remainingFields.map { $0.name })")
        self.fieldsToAssign = remainingFields

        // Trigger Assignment UI ONLY if needed
        if !remainingFields.isEmpty {
            self.currentAssignmentIndex = 0
            print("ViewModel: Setting isAssigningFields = true.")
            self.isAssigningFields = true // Present the assignment sheet
            print("Triggering guided field assignment UI.")
        } else {
            print("No fields require manual assignment. Setting assignmentFlowComplete = true.")
            self.isAssigningFields = false
            self.assignmentFlowComplete = true // Mark flow as complete
        }
    }


    /// Resets state and triggers camera again from OCR preview.
    func retakePhoto() {
        print("ViewModel: retakePhoto called.")
        resetScanState(clearImage: true) // Clear image and results
        showOcrPreview = false // Dismiss preview
        showCamera = true // Show camera again
        print("ViewModel: showCamera set to true for retake.")
    }

    /// Called by FieldAssignmentView when user assigns or skips a field.
    func handleAssignment(assignedValue: String?) {
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
        case "manufacturingDateString":
            parseAndAssignMfgDate(fromString: valueToAssign) // Use helper to parse
        default: print("ViewModel Warning: Unknown field key during assignment: \(currentField.key)")
        }

        // Track the assigned OCR value (if not skipped and not empty)
        if let originalValue = assignedValue, !originalValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
             assignedOcrValues.insert(originalValue)
             print("ViewModel: Added '\(originalValue)' to assigned values. Current set: \(assignedOcrValues)")
        }

        // Move to the next field or finish
        currentAssignmentIndex += 1
        if currentAssignmentIndex >= fieldsToAssign.count {
            finishAssignment()
        } else {
            print("ViewModel: Moving to next field assignment: \(fieldsToAssign[currentAssignmentIndex].name)")
            // Sheet UI updates automatically based on index change triggering view update
        }
    }

    /// Called when the assignment flow finishes (all fields done) or is cancelled.
     func finishAssignment() {
        print("ViewModel: finishAssignment called.")
        // Mark flow complete ONLY if assignment finished successfully (reached end)
        if currentAssignmentIndex >= fieldsToAssign.count {
            print("ViewModel: Setting assignmentFlowComplete = true in finishAssignment.")
            assignmentFlowComplete = true
        } else {
             print("ViewModel: Assignment cancelled early.")
             assignmentFlowComplete = false // Not complete if cancelled
        }
        // Dismiss the sheet by setting the controlling state to false
        print("ViewModel: Setting isAssigningFields = false to dismiss sheet.")
        isAssigningFields = false
        isProcessing = false // Ensure processing indicator is off
    }

     /// Triggers the presentation of the manual view. (Currently unused)
    func displayManual() {
        print("ViewModel: Displaying manual.")
        showManualView = true
    }

    /// Action for the new "Confirm" button.
    func confirmEquipmentInfo() {
        print("ViewModel: confirmEquipmentInfo called. Setting showConfirmationDestination = true.")
        // In a real app, save data to Salesforce/backend here.
        self.showConfirmationDestination = true // Trigger navigation
    }


    // MARK: - Internal Helper Functions

    /// Resets ALL relevant state variables for a new scan.
    func resetScanState(clearImage: Bool) {
        print("ViewModel: Resetting state (clearImage: \(clearImage)).")
        self.assignmentFlowComplete = false // Reset completion flag
        if clearImage { self.capturedEquipmentImage = nil }
        self.ocrObservations = []
        self.allOcrStrings = []
        self.fieldsToAssign = []
        self.currentAssignmentIndex = 0
        self.isAssigningFields = false
        self.isProcessing = false
        self.assignedOcrValues = Set<String>()
        self.initialAutoParsedData = [:]
        self.showOcrPreview = false
        self.showAutoParseReview = false
        self.showManualView = false
        self.showConfirmationDestination = false
        clearFormFields()
    }

    /// Clears all form field state variables.
    private func clearFormFields() {
        make = ""; model = ""; serialNumber = ""; manufacturingDateString = ""
        voltageString = ""; ampsString = ""; pressureString = ""
        print("ViewModel: Form fields cleared.")
    }

    /// Performs ONLY the OCR request on the image.
    private func performOCROnly(on image: UIImage) async {
        guard let cgImage = image.cgImage else {
            print("ViewModel Error: Failed to get CGImage.")
            await MainActor.run { isProcessing = false }
            return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("ViewModel: performOCROnly starting.")

        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        do {
            let results: [RecognizedTextObservation] = try await textRequest.perform(on: cgImage, orientation: imageOrientation)
            await MainActor.run {
                print("ViewModel OCR success: Found \(results.count) observations.")
                self.ocrObservations = results
                if !results.isEmpty {
                     print("ViewModel: Setting showOcrPreview = true.")
                     self.showOcrPreview = true
                     // isProcessing remains true until user proceeds/retakes
                } else {
                     print("ViewModel: No OCR results, setting showOcrPreview=false, isProcessing=false.")
                     self.showOcrPreview = false
                     isProcessing = false
                }
                 print("ViewModel: OCR function finished on MainActor.")
            }
        } catch {
            print("ViewModel Error: Failed to perform Vision request: \(error.localizedDescription)")
            await MainActor.run {
                self.ocrObservations = []
                isProcessing = false
                 print("ViewModel: OCR function finished with error on MainActor.")
            }
        }
    }

    /// Parses only high-confidence patterns (Date, V, A, PSI) from OCR results.
    func parseHighConfidenceInfo(from observations: [RecognizedTextObservation]) -> (parsedData: [String: String], allLines: [String]) {
        var parsedData: [String: String] = [:]
        let allTextLines = observations.compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        print("--- Raw OCR Lines for Parsing (High Confidence Pass) ---")
        allTextLines.forEach { print($0) }
        print("--------------------------------------------------------")

        for line in allTextLines {
            // Pressure
            if parsedData["pressure"] == nil,
               let match = line.range(of: #"(\d+(\.\d+)?\s?PSI)"#, options: [.regularExpression, .caseInsensitive]),
               String(line[match]).rangeOfCharacter(from: .decimalDigits) != nil {
                 parsedData["pressure"] = String(line[match]).trimmingCharacters(in: .whitespaces)
                 print("Regex found Pressure: \(parsedData["pressure"]!)")
            }
            // Voltage
            if parsedData["voltage"] == nil,
               let match = line.range(of: #"(\d+(\.\d+)?\s?V(AC|DC)?)"#, options: [.regularExpression, .caseInsensitive]),
               String(line[match]).rangeOfCharacter(from: .decimalDigits) != nil {
                 parsedData["voltage"] = String(line[match]).trimmingCharacters(in: .whitespaces)
                 print("Regex found Voltage: \(parsedData["voltage"]!)")
            }
             // Amps
             if parsedData["amps"] == nil,
                let match = line.range(of: #"(\d+(\.\d+)?\s?A(mps)?)"#, options: [.regularExpression, .caseInsensitive]),
                 String(line[match]).rangeOfCharacter(from: .decimalDigits) != nil {
                  parsedData["amps"] = String(line[match]).trimmingCharacters(in: .whitespaces)
                  print("Regex found Amps: \(parsedData["amps"]!)")
             }
             // Mfg Date (Use strict parser here)
              if parsedData["mfgDate"] == nil,
                 let dateValue = extractYearMonthStrict(from: line) {
                   parsedData["mfgDate"] = dateValue
                   print("Regex found Mfg Date: \(dateValue) in line: \(line)")
              }
        }
        return (parsedData, allTextLines)
    }

    /// Updates the main form's @Published properties based on parsed/assigned data.
    private func updateFormFields(with data: [String: String]) {
        print("Updating form fields with data: \(data)")
        // Update only if value exists in the dictionary and is not empty
        if let val = data["make"], !val.isEmpty { self.make = val }
        if let val = data["model"], !val.isEmpty { self.model = val }
        if let val = data["serialNumber"], !val.isEmpty { self.serialNumber = val }
        if let val = data["mfgDate"], !val.isEmpty { self.manufacturingDateString = val }
        if let val = data["voltage"], !val.isEmpty { self.voltageString = val }
        if let val = data["amps"], !val.isEmpty { self.ampsString = val }
        if let val = data["pressure"], !val.isEmpty { self.pressureString = val }
    }


    /// Orientation Helper.
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

    /// Helper to find value after a keyword.
    private func findValueAfterKeyword(keyword: String, in lines: [String], excluding usedValues: Set<String>) -> String? {
        guard let keywordIndex = lines.firstIndex(where: { $0.localizedCaseInsensitiveContains(keyword) }) else {
            return nil
        }
        let potentialValueIndex = keywordIndex + 1
        if potentialValueIndex < lines.count {
            let potentialValue = lines[potentialValueIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if !potentialValue.isEmpty && !usedValues.contains(potentialValue) {
                // Basic check to avoid assigning the keyword itself if it's on its own line
                if !potentialValue.localizedCaseInsensitiveContains(keyword) {
                    return potentialValue
                } else {
                     print("Value after '\(keyword)' ('\(potentialValue)') seems to be the keyword itself.")
                }
            } else {
                 print("Value after '\(keyword)' ('\(potentialValue)') is empty or already used.")
            }
        }
        return nil
    }

    /// Helper to parse YYYY-MM from a string (Original, less strict).
    private func extractYearMonth(from text: String) -> String? {
        let pattern = #"(\d{4}[-/]\d{1,2})"# // Original pattern
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange) {
                if let range = Range(match.range(at: 1), in: text) {
                    return String(text[range])
                }
            }
        } catch {
            print("Error creating regex for date parsing: \(error)")
        }
        return nil
    }

    /// Extracts YYYY-MM or YYYY/MM pattern *only if it's the entire string*.
    private func extractYearMonthStrict(from text: String) -> String? {
        let pattern = #"^(\d{4}[-/]\d{1,2})$"# // Added ^ and $ anchors
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [])
            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: nsRange) {
                if let range = Range(match.range(at: 1), in: text) { // Get group 1
                    return String(text[range])
                }
            }
        } catch {
            print("Error creating strict regex for date parsing: \(error)")
        }
        return nil
    }

    /// Helper to parse and assign Mfg Date.
    private func parseAndAssignMfgDate(fromString value: String?) {
        guard let inputString = value, !inputString.isEmpty else {
            self.manufacturingDateString = "" // Clear if input is nil or empty
            return
        }
        // Try parsing with the general extractor first
        if let parsedDate = extractYearMonth(from: inputString) {
            self.manufacturingDateString = parsedDate
            print("Parsed Mfg Date: \(parsedDate) from input: \(inputString)")
        } else {
            // If parsing fails, assign the raw string
            self.manufacturingDateString = inputString
            print("Could not parse YYYY-MM from '\(inputString)', assigning raw value.")
        }
    }

} // End ViewModel

