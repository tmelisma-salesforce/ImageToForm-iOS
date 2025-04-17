//
//  MeterReadingView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision
import CoreGraphics

// Ensure Deployment Target is iOS 18.0+

struct MeterReadingView: View {
    // MARK: - State Variables
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var isProcessing = false
    @State private var detectedNumbers: [String] = []
    @State private var selectedReading: String? = nil
    @State private var confirmationMessage: String = "" // NEW: Holds confirmation text

    var body: some View {
        VStack(spacing: 0) { // Use spacing 0 to make List and confirmation section adjacent
            // List to display detected numbers and allow selection
            List {
                Section("Select Meter Reading (Largest Auto-Selected):") {
                    if isProcessing {
                        HStack { Spacer(); ProgressView(); Spacer() }
                    } else if detectedNumbers.isEmpty {
                        Text(capturedImage == nil ? "Tap 'Scan Meter' below." : "No numbers detected in image.")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(detectedNumbers, id: \.self) { numberString in
                            Button {
                                selectedReading = numberString
                                confirmationMessage = "" // Clear confirmation when selection changes
                                print("User manually selected reading: \(numberString)")
                            } label: {
                                HStack {
                                    Text(numberString)
                                        .fontWeight(selectedReading == numberString ? .bold : .regular)
                                        .foregroundColor(selectedReading == numberString ? .blue : .primary)
                                    Spacer()
                                    if selectedReading == numberString {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            // Make the list flexible in size but not necessarily take all space
            // .layoutPriority(1) // Optional: Give list priority if needed

            // --- NEW: Confirmation Section ---
            VStack {
                Divider() // Visual separator

                HStack {
                    Text("Selected:")
                        .font(.headline)
                    // Display the selected reading or "None"
                    Text(selectedReading ?? "None")
                        .font(.body.monospacedDigit()) // Use monospaced for numbers
                        .foregroundColor(selectedReading == nil ? .gray : .primary)
                    Spacer() // Pushes button to the right
                    Button("Confirm Reading") {
                        // Action: Set confirmation message (simulate saving)
                        if let reading = selectedReading {
                            confirmationMessage = "Reading '\(reading)' stored successfully!"
                            print("Confirmed reading: \(reading)")
                            // Optionally disable button after confirm, or clear selection?
                            // For now, just show message. User can re-confirm if desired.
                        }
                    }
                    // Enable button only if a reading IS selected
                    .disabled(selectedReading == nil)
                    .buttonStyle(.borderedProminent)
                }
                .padding([.horizontal, .top]) // Add padding to this HStack

                // Display the confirmation message if it's not empty
                if !confirmationMessage.isEmpty {
                    Text(confirmationMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal)
                        .padding(.top, 5)
                        .transition(.opacity) // Add a subtle fade
                }

                Spacer().frame(height: 10) // Add some space at the bottom
            }
            .background(.regularMaterial) // Give confirmation area a distinct background
            // --- END Confirmation Section ---

            // Scan button might be better placed above confirmation area or within it
            // Let's keep it at the very bottom for now.
            Spacer() // Pushes Scan button down

            Button {
                self.detectedNumbers = []
                self.selectedReading = nil
                self.capturedImage = nil
                self.confirmationMessage = "" // Clear confirmation on new scan
                self.showCamera = true
            } label: {
                Label("Scan Meter", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding() // Add padding below the button

        } // End main VStack
        .navigationTitle("Read Meter")
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $capturedImage, isFrontCamera: false) // Specify false
        }
        .onChange(of: capturedImage) { _, newImage in // iOS 17+ signature
            if let image = newImage {
                print("MeterReadingView: onChange detected new image. Launching processing Task.")
                Task {
                    await MainActor.run {
                        isProcessing = true
                        detectedNumbers = []
                        selectedReading = nil
                        confirmationMessage = "" // Clear confirmation message
                    }
                    await performVisionRequest(on: image) // This populates detectedNumbers and auto-selects selectedReading
                    await MainActor.run {
                        isProcessing = false
                    }
                }
            }
        }

    } // End body

    // MARK: - Vision Processing Function (Unchanged from previous step)

    @MainActor
    private func performVisionRequest(on image: UIImage) async {
        guard let cgImage = image.cgImage else {
            print("MeterReadingView Error: Failed to get CGImage.")
            return
        }
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("MeterReadingView DEBUG: Using CGImagePropertyOrientation: \(imageOrientation.rawValue)")
        print("MeterReadingView: Starting Vision Text Recognition (New API)...")
        var textRequest = RecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true

        var numbersOnly: [String] = []
        var autoSelectedReading: String? = nil

        do {
            print("MeterReadingView: Performing RecognizeTextRequest directly...")
            let results: [RecognizedTextObservation] = try await textRequest.perform(
                on: cgImage,
                orientation: imageOrientation
            )
            print("MeterReadingView OCR success: Found \(results.count) raw observations.")

            // Filter for Numbers
            for observation in results {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let cleanedText = topCandidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if Double(cleanedText) != nil {
                    numbersOnly.append(cleanedText)
                }
            }
            print("Found \(numbersOnly.count) potential numbers.")

            // Auto-select Largest Number
            if !numbersOnly.isEmpty {
                autoSelectedReading = numbersOnly.max { (str1, str2) -> Bool in
                    let num1 = Double(str1) ?? -Double.infinity
                    let num2 = Double(str2) ?? -Double.infinity
                    return num1 < num2
                }
                print("Automatically selected largest number string: \(autoSelectedReading ?? "None")")
            }

        } catch {
            print("MeterReadingView Error: Failed to perform Vision request: \(error.localizedDescription)")
            numbersOnly = []
            autoSelectedReading = nil
        }

        // Update State (already on @MainActor)
        self.detectedNumbers = numbersOnly
        self.selectedReading = autoSelectedReading // Set initial selection

        print("MeterReadingView: Vision processing function finished.")
    } // End performVisionRequest


    // --- Orientation Helper (Unchanged) ---
    private func cgOrientation(from uiOrientation: UIImage.Orientation) -> CGImagePropertyOrientation {
         switch uiOrientation {
            case .up: return .up; case .down: return .down; case .left: return .left; case .right: return .right;
            case .upMirrored: return .upMirrored; case .downMirrored: return .downMirrored; case .leftMirrored: return .leftMirrored; case .rightMirrored: return .rightMirrored;
            @unknown default: print("Warning: Unknown UIImage.Orientation (\(uiOrientation.rawValue)), defaulting to .up"); return .up
         }
    }

} // End MeterReadingView struct

// MARK: - Preview
#Preview {
    NavigationView {
        MeterReadingView()
    }
}
