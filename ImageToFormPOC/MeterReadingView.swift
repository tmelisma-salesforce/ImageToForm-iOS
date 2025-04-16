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
    // visionResults could be removed if bounding boxes are definitely not needed here
    // @State private var visionResults: [RecognizedTextObservation] = []
    @State private var isProcessing = false
    @State private var detectedNumbers: [String] = [] // Holds filtered number strings
    @State private var selectedReading: String? = nil // Holds the user's selection (now auto-set initially)

    var body: some View {
        VStack {
            // List to display detected numbers and allow selection
            List {
                Section("Select Meter Reading:") { // Updated header
                    if isProcessing {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    } else if detectedNumbers.isEmpty {
                        Text(capturedImage == nil ? "Tap 'Scan Meter' below." : "No numbers detected in image.")
                            .foregroundColor(.gray)
                    } else {
                        // Display FILTERED numbers as Buttons
                        ForEach(detectedNumbers, id: \.self) { numberString in
                            Button {
                                // Action: Allow user to override auto-selection
                                selectedReading = numberString
                                print("User manually selected reading: \(numberString)")
                            } label: {
                                // Row content: Number and checkmark if selected
                                HStack {
                                    Text(numberString)
                                        // Highlight selected number
                                        .fontWeight(selectedReading == numberString ? .bold : .regular)
                                        .foregroundColor(selectedReading == numberString ? .blue : .primary)
                                    Spacer()
                                    if selectedReading == numberString {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                    }
                                }
                                .contentShape(Rectangle()) // Make entire row tappable
                            }
                            .buttonStyle(.plain) // Use plain style for list appearance
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())

            Spacer() // Pushes button to bottom

            Button {
                self.detectedNumbers = [] // Clear previous numbers
                self.selectedReading = nil // Clear previous selection
                self.capturedImage = nil
                self.showCamera = true
            } label: {
                Label("Scan Meter", systemImage: "camera.viewfinder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding()

        } // End main VStack
        .navigationTitle("Read Meter")
        .sheet(isPresented: $showCamera) {
            ImagePicker(selectedImage: $capturedImage)
        }
        .onChange(of: capturedImage) { _, newImage in // iOS 17+ signature
            if let image = newImage {
                print("MeterReadingView: onChange detected new image. Launching processing Task.")
                Task {
                    await MainActor.run {
                        isProcessing = true
                        detectedNumbers = [] // Clear old numbers
                        selectedReading = nil // Clear old selection
                    }
                    await performVisionRequest(on: image)
                    await MainActor.run {
                        isProcessing = false
                    }
                }
            }
        }
        // Optional overlay for processing
        // .overlay { if isProcessing { ProcessingIndicatorView() } }

    } // End body

    // MARK: - Vision Processing Function (UPDATED with Auto-Selection)

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

        var numbersOnly: [String] = [] // Temporary local array
        var autoSelectedReading: String? = nil // Temporary local var for selection

        do {
            print("MeterReadingView: Performing RecognizeTextRequest directly...")
            let results: [RecognizedTextObservation] = try await textRequest.perform(
                on: cgImage,
                orientation: imageOrientation
            )
            print("MeterReadingView OCR success: Found \(results.count) raw observations.")

            // --- FILTER FOR NUMBERS ---
            for observation in results {
                guard let topCandidate = observation.topCandidates(1).first else { continue }
                let rawText = topCandidate.string
                let cleanedText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
                // Consider more cleaning? e.g., removing commas for larger numbers?
                // let veryCleanText = cleanedText.replacingOccurrences(of: ",", with: "")
                // if Double(veryCleanText) != nil { ... }

                if Double(cleanedText) != nil {
                    print("Found number: \(cleanedText)")
                    numbersOnly.append(cleanedText)
                }
            }
            print("Found \(numbersOnly.count) potential numbers.")
            // --- END FILTER ---

            // --- AUTO-SELECT LARGEST NUMBER ---
            if !numbersOnly.isEmpty {
                // Use max(by:) with a closure that compares the Double values of the strings
                autoSelectedReading = numbersOnly.max { (str1, str2) -> Bool in
                    // Safely convert to Double for comparison, default to very small number if conversion fails
                    let num1 = Double(str1) ?? -Double.infinity
                    let num2 = Double(str2) ?? -Double.infinity
                    return num1 < num2 // For max(by:), return true if first element is smaller
                }
                print("Automatically selected largest number string: \(autoSelectedReading ?? "None")")
            }
            // --- END AUTO-SELECT ---

        } catch {
            print("MeterReadingView Error: Failed to perform Vision request: \(error.localizedDescription)")
            // Ensure state is cleared on error
            numbersOnly = []
            autoSelectedReading = nil
        }

        // --- Update State Variables ---
        // Update state AFTER all processing (filtering and auto-select) is done
        self.detectedNumbers = numbersOnly
        self.selectedReading = autoSelectedReading
        // --- End State Update ---

        print("MeterReadingView: Vision processing function finished.")
    } // End performVisionRequest


    // --- Orientation Helper (Copied from ContentView) ---
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
