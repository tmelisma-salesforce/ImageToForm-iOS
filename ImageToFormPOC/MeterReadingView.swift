//
//  MeterReadingView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Required for text recognition (OCR) capabilities.
import CoreGraphics // Required for CGImagePropertyOrientation.

// Requires iOS 18.0+ for the Swift Concurrency-based Vision APIs.

/// A view for capturing an image of a meter and extracting the reading using OCR.
struct MeterReadingView: View {

    // MARK: - State Variables

    /// Controls the presentation of the camera/image picker sheet.
    @State private var showCamera = false
    /// Stores the image captured by the user via the camera or photo library.
    @State private var capturedImage: UIImage? = nil
    /// Indicates whether the OCR process is currently running.
    @State private var isProcessing = false
    /// Stores the numerical strings detected by the OCR process.
    @State private var detectedNumbers: [String] = []
    /// Stores the currently selected meter reading from the detected numbers.
    @State private var selectedReading: String? = nil
    /// Displays a confirmation message after the user confirms a reading.
    @State private var confirmationMessage: String = ""

    /// The target value used to automatically pre-select the most likely meter reading from the OCR results.
    private let targetValue: Double = 10000.0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {

            // Display the results list and action buttons if an image has been captured or is processing.
            if capturedImage != nil || isProcessing {

                // Section displaying detected numbers or processing indicator.
                List {
                    Section("Select Meter Reading") {
                        if isProcessing {
                            // Show a progress indicator while OCR is running.
                            HStack { Spacer(); ProgressView(); Spacer() }
                        } else if detectedNumbers.isEmpty {
                            // Inform the user if no numbers were found.
                            Text("No numbers detected in image.")
                                .foregroundColor(.gray)
                        } else {
                            // Display each detected number as a selectable button.
                            ForEach(detectedNumbers, id: \.self) { numberString in
                                Button {
                                    selectedReading = numberString
                                    confirmationMessage = "" // Clear previous confirmation on new selection.
                                } label: {
                                    HStack {
                                        Text(numberString)
                                            .font(.title)
                                            .fontWeight(selectedReading == numberString ? .bold : .regular)
                                            .foregroundColor(selectedReading == numberString ? .blue : .primary)
                                        Spacer()
                                        // Show a checkmark next to the selected reading.
                                        if selectedReading == numberString {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                                .font(.title)
                                        }
                                    }
                                    .padding(.vertical, 5)
                                }
                                .buttonStyle(.plain) // Use plain style to make it look like a list item.
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle()) // Apply standard grouped list styling.

                // Display the confirmation message if one exists.
                if !confirmationMessage.isEmpty {
                    Text(confirmationMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal)
                        .transition(.opacity) // Animate the appearance/disappearance.
                }

                // Action buttons displayed after a scan.
                HStack {
                    // Button to clear results and initiate a new scan.
                    Button {
                        scanButtonTapped()
                    } label: {
                        Label("Re-scan Meter", systemImage: "camera.viewfinder")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Spacer()

                    // Button to confirm the selected reading.
                    Button("Confirm Reading") {
                        if let reading = selectedReading {
                            confirmationMessage = "Reading '\(reading)' stored successfully!"
                            // In a real app, this would likely save the reading and navigate away.
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedReading == nil) // Disable if no reading is selected.
                }
                .padding() // Add padding around the button row.

            } else {
                // Initial state shown before any image is captured.
                Spacer()
                Text("Tap button to scan the meter.")
                    .font(.headline)
                    .foregroundColor(.gray)
                Spacer()
                // Button to initiate the first scan.
                Button {
                   scanButtonTapped()
                } label: {
                    Label("Scan Meter", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding()
                Spacer()
            }

        } // End main VStack
        .navigationTitle("Read Meter")
        // Present the ImagePicker view as a sheet when showCamera is true.
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $capturedImage, isFrontCamera: false) // Use rear camera for meters.
        }
        // Observe changes to the capturedImage property.
        .onChange(of: capturedImage) { _, newImage in
            if let image = newImage {
                // When a new image is set, start the OCR processing task.
                Task {
                    // Reset UI state before processing.
                    await MainActor.run {
                        isProcessing = true
                        detectedNumbers = []
                        selectedReading = nil
                        confirmationMessage = ""
                    }
                    // Perform the OCR request on the captured image.
                    await performVisionRequest(on: image)
                    // Update UI state after processing is complete.
                    await MainActor.run {
                        isProcessing = false
                    }
                }
            }
        }

    } // End body

    // MARK: - Actions

    /// Resets the state and triggers the presentation of the camera/image picker.
    private func scanButtonTapped() {
        self.detectedNumbers = []
        self.selectedReading = nil
        self.capturedImage = nil // Clear the previous image to reset the UI state.
        self.confirmationMessage = ""
        self.showCamera = true
    }


    // MARK: - Vision Processing Function

    /// Performs the OCR request using the Vision framework on the provided image.
    @MainActor // Ensures UI updates triggered within happen on the main thread.
    private func performVisionRequest(on image: UIImage) async {
        guard let cgImage = image.cgImage else {
            // Failed to get the underlying CGImage, cannot proceed.
            // In a real app, show an error message to the user.
            return
        }
        // Determine the correct orientation for the Vision request.
        let imageOrientation = cgOrientation(from: image.imageOrientation)

        // Configure the text recognition request.
        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate // Prioritize accuracy over speed.
        textRequest.usesLanguageCorrection = true // Enable language correction for potentially better results.

        var numbersFound: [String] = []
        var autoSelectedReading: String? = nil

        do {
            // Perform the text recognition request asynchronously.
            let results: [RecognizedTextObservation] = try await textRequest.perform(
                on: cgImage,
                orientation: imageOrientation
            )

            // Process the observations returned by the Vision request.
            for observation in results {
                // Get the top candidate string for each observation.
                guard let topCandidate = observation.topCandidates(1).first else { continue }

                // Clean the text: remove whitespace and optionally commas.
                let cleanedText = topCandidate.string
                                      .trimmingCharacters(in: .whitespacesAndNewlines)
                                      .replacingOccurrences(of: ",", with: "") // Remove commas if present.

                // Check if the cleaned text represents a valid number.
                if Double(cleanedText) != nil {
                    numbersFound.append(cleanedText)
                }
            }

            // Auto-select the number closest to the target value if any numbers were found.
            if !numbersFound.isEmpty {
                var minDifference = Double.infinity
                var closestNumberString: String? = nil

                for numberString in numbersFound {
                    if let numberValue = Double(numberString) {
                        let difference = abs(numberValue - targetValue)
                        if difference < minDifference {
                            minDifference = difference
                            closestNumberString = numberString
                        }
                    }
                }
                autoSelectedReading = closestNumberString
            }

        } catch {
            // Handle errors during the Vision request.
            // In a real app, show an error message to the user.
            numbersFound = []
            autoSelectedReading = nil
        }

        // Update the state variables on the main thread with the results.
        // Sort the detected numbers numerically for display.
        self.detectedNumbers = numbersFound.sorted {
            (Double($0) ?? -Double.infinity) < (Double($1) ?? -Double.infinity)
        }
        // Set the initially selected reading based on proximity to the target value.
        self.selectedReading = autoSelectedReading

    } // End performVisionRequest


    // MARK: - Orientation Helper

    /// Converts a UIImage.Orientation to its corresponding CGImagePropertyOrientation,
    /// required by the Vision framework.
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
                // Handle potential future cases gracefully.
                return .up
         }
    }

} // End MeterReadingView struct

// MARK: - Preview
#Preview {
    // Provides a preview of the MeterReadingView within a NavigationView for development.
    NavigationView {
        MeterReadingView()
    }
}
