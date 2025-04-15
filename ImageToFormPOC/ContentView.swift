//
//  ContentView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision // Keep Vision import
import CoreGraphics // Import for CGImagePropertyOrientation

struct ContentView: View {

    // MARK: - State Variables
    @State private var showCamera = false
    @State private var capturedImage: UIImage? = nil
    @State private var visionResults: [VNRecognizedTextObservation] = []
    @State private var isProcessing = false

    // MARK: - Body
    var body: some View {
        NavigationView {
            VStack {
                // --- Conditional View: Welcome OR Results ---
                if capturedImage == nil {
                    WelcomeView(showCamera: $showCamera, capturedImage: $capturedImage, visionResults: $visionResults)
                } else {
                    ResultsView(
                        capturedImage: $capturedImage,
                        visionResults: $visionResults,
                        isProcessing: $isProcessing,
                        showCamera: $showCamera // Pass showCamera binding for "Scan New"
                    )
                }
            } // End main VStack
            .navigationTitle(capturedImage == nil ? "Welcome" : "Scan Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if capturedImage != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Scan New") {
                            resetScan()
                        }
                    }
                }
            } // End Toolbar
            .fullScreenCover(isPresented: $showCamera) {
                ImagePicker(selectedImage: $capturedImage)
            }
            .onChange(of: capturedImage) { _ , newImage in // iOS 17+ signature
                if let image = newImage {
                    print("onChange detected new image. Setting isProcessing=true.")
                    isProcessing = true
                    performVisionRequest(on: image) // Call the updated function
                } else {
                    print("onChange detected image became nil (likely reset).")
                }
            }
            .overlay {
                if isProcessing {
                    ProcessingIndicatorView()
                }
            } // End overlay
        } // End NavigationView
        .navigationViewStyle(.stack)
    } // End body

    // MARK: - Helper Functions

    private func resetScan() {
        print("Resetting scan state.")
        self.capturedImage = nil
        self.visionResults = []
        // Decide if you want to immediately show camera after reset:
        // self.showCamera = true
    }

    // MARK: - Vision Processing Function (UPDATED)

    /// Performs text recognition on the provided image, now handling orientation.
    private func performVisionRequest(on image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Error: Failed to get CGImage from input UIImage.")
            DispatchQueue.main.async { isProcessing = false }
            return
        }

        // --- ORIENTATION HANDLING START ---
        // 1. Log the original UIImage orientation
        print("DEBUG: UIImage Orientation raw value: \(image.imageOrientation.rawValue)")

        // 2. Convert UIImage.Orientation to CGImagePropertyOrientation
        let imageOrientation = cgOrientation(from: image.imageOrientation)
        print("DEBUG: Converted to CGImagePropertyOrientation: \(imageOrientation.rawValue)")
        // --- ORIENTATION HANDLING END ---


        print("Starting Vision processing on background thread...")
        DispatchQueue.global(qos: .userInitiated).async {
            // --- MODIFIED HANDLER INIT ---
            // 3. Create handler WITH the determined orientation
            let requestHandler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: imageOrientation, // Pass the correct orientation
                options: [:]
            )
            // --- END MODIFIED HANDLER INIT ---

            let textRequest = VNRecognizeTextRequest { (request, error) in
                DispatchQueue.main.async {
                    print("Vision processing finished. Handling results on main thread...")
                    isProcessing = false
                    if let error = error {
                        print("Vision Error: \(error.localizedDescription)")
                        self.visionResults = []
                        return
                    }
                    guard let observations = request.results as? [VNRecognizedTextObservation] else {
                        print("Error: Could not cast Vision results.")
                        self.visionResults = []
                        return
                    }
                    print("Vision success: Found \(observations.count) text observations.")
                    self.visionResults = observations
                }
            }
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true
            do {
                try requestHandler.perform([textRequest])
            } catch {
                DispatchQueue.main.async {
                    print("Error: Failed to perform Vision request: \(error.localizedDescription)")
                    self.visionResults = []
                    isProcessing = false
                }
            }
        } // End background thread dispatch
    } // End performVisionRequest

    // MARK: - Orientation Helper (NEW)

    /// Converts UIImage.Orientation to the corresponding CGImagePropertyOrientation required by Vision framework.
    /// - Parameter uiOrientation: The UIImage.Orientation value.
    /// - Returns: The equivalent CGImagePropertyOrientation value.
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
                print("Warning: Unknown UIImage.Orientation encountered (\(uiOrientation.rawValue)), defaulting to .up")
                return .up // Default orientation
        }
    }

} // End ContentView

// MARK: - Subviews (Unchanged from previous step)

struct WelcomeView: View {
    @Binding var showCamera: Bool
    @Binding var capturedImage: UIImage?
    @Binding var visionResults: [VNRecognizedTextObservation]

    var body: some View {
        VStack {
            Spacer()
            Text("Image Text Scanner POC").font(.largeTitle).padding(.bottom, 5)
            Text("Tap 'Start Scan' to capture an image and extract text.").font(.body).foregroundColor(.secondary).multilineTextAlignment(.center).padding([.leading, .trailing])
            Spacer()
            Button("Start Scan") {
                self.capturedImage = nil
                self.visionResults = []
                self.showCamera = true
            }
            .padding().buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}

struct ResultsView: View {
    @Binding var capturedImage: UIImage?
    @Binding var visionResults: [VNRecognizedTextObservation]
    @Binding var isProcessing: Bool
    @Binding var showCamera: Bool // Although not directly used, passed for consistency perhaps

    var body: some View {
        VStack {
            ZStack {
                if let image = capturedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .overlay(BoundingBoxOverlay(observations: visionResults)) // Apply overlay
                } else {
                    Text("Error displaying image.")
                }
            }
            .frame(minHeight: 150, maxHeight: 300)
            .border(Color.gray, width: 1)
            .padding([.leading, .trailing, .bottom])

            List {
                Section("Extracted Text:") {
                    if visionResults.isEmpty && !isProcessing {
                         Text("Processing complete. No text found.")
                            .foregroundColor(.gray)
                    } else if isProcessing {
                         Text("Processing...") // Should be covered by overlay
                            .foregroundColor(.gray)
                    } else {
                         ForEach(visionResults, id: \.uuid) { observation in
                             Text(observation.topCandidates(1).first?.string ?? "Error reading text")
                         }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
    }
}

struct ProcessingIndicatorView: View {
    var body: some View {
        ZStack {
            Color(white: 0, opacity: 0.5).edgesIgnoringSafeArea(.all)
            ProgressView("Processing...")
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .padding()
                .background(Color.black.opacity(0.7))
                .foregroundColor(.white)
                .cornerRadius(10)
                .shadow(radius: 10)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
