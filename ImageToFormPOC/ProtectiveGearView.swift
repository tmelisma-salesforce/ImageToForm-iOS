//
//  ProtectiveGearView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision
import CoreGraphics

// Ensure Deployment Target is iOS 18.0+ or compatible

struct ProtectiveGearView: View {

    // Use @StateObject for the ViewModel
    @StateObject private var viewModel = ProtectiveGearViewModel()

    // Define required gear (can be moved to ViewModel if desired)
    let requiredGear = ["Helmet", "Gloves", "Boots"]
    // Define PPE labels expected from the model (lowercase for matching)
    // This MUST align with your model's capabilities and labels in ViewModel
    let ppeLabels: Set<String> = ["helmet", "glove", "boot", "safety vest", "safety glasses", "face shield", "sports ball"] // Example

    // MARK: - Body
    var body: some View {
        // Main VStack now composes the extracted sections
        VStack(alignment: .leading) {
            requiredGearSection // Extracted View
            Divider()
            selfieCaptureSection // Extracted View
            scanButtonSection // Extracted View
            resultsSection // Extracted View
            Spacer() // Pushes content up
        }
        .padding() // Overall padding
        .navigationTitle("Verify Protective Gear")
        // --- Modifiers read state from ViewModel ---
        .fullScreenCover(isPresented: $viewModel.showFrontCamera) {
            // Ensure ImagePicker.swift exists and supports isFrontCamera
            ImagePicker(selectedImage: $viewModel.selfieImage, isFrontCamera: true)
        }
         // onChange Modifier to trigger ViewModel action
         .onChange(of: viewModel.selfieImage) { _, newImage in
              if let image = newImage {
                   print("ProtectiveGearView: onChange detected new image. Calling viewModel.imageCaptured.")
                   viewModel.imageCaptured(image) // Call ViewModel method
              } else {
                   print("ProtectiveGearView: onChange detected selfieImage became nil.")
                   // ViewModel's resetState handles clearing detections if needed
              }
         }
         // Sheet for Detection Preview (reads state from ViewModel)
         .sheet(isPresented: $viewModel.showDetectionPreview) {
              if let image = viewModel.selfieImage {
                   // Ensure ObjectDetectionPreviewView.swift exists
                   ObjectDetectionPreviewView(
                       image: image,
                       detectedObjects: viewModel.detectedObjects, // Pass ViewModel data
                       onRetake: viewModel.retakePhoto, // Call ViewModel action
                       onProceed: viewModel.proceedFromPreview // Call ViewModel action
                   )
              }
         }
         // Overlay for Processing Indicator (reads state from ViewModel)
         .overlay { if viewModel.isProcessing { ProcessingIndicatorView() } } // Ensure this view exists

    } // End body

    // MARK: - Extracted UI Sections (Computed Properties)

    /// Displays the list of required PPE.
    private var requiredGearSection: some View {
        VStack(alignment: .leading) {
            Text("Required Personal Protective Equipment (PPE):")
                .font(.headline)
                .padding(.bottom, 5)
            ForEach(requiredGear, id: \.self) { item in
                Label(item, systemImage: "shield.lefthalf.filled") // Example icon
            }
            .padding(.leading)
        }
        .padding(.bottom) // Add padding below this section
    }

    /// Displays the selfie image or placeholder, and overlay for PPE boxes.
    private var selfieCaptureSection: some View {
        VStack(alignment: .leading) {
            Text("Capture Selfie:")
                .font(.headline)
                .padding(.bottom, 5)

            ZStack {
                // Read image from ViewModel
                if let image = viewModel.selfieImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        // Overlay for FINAL PPE boxes (reads from ViewModel)
                        .overlay(ppeBoundingBoxes) // This computed var also reads ViewModel state
                        .overlay(alignment: .topTrailing) {
                             // Call ViewModel's reset function
                             Button { viewModel.resetState(clearImage: true) } label: {
                                 Image(systemName: "xmark.circle.fill")
                                     .foregroundColor(.gray)
                                     .background(Color.white.opacity(0.8))
                                     .clipShape(Circle())
                                     .padding(5)
                             }
                         }
                } else {
                    // Placeholder View
                    Text("Take a selfie to check your gear.")
                        .foregroundColor(.gray)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color(uiColor: .systemGray6)))
                }
            } // End ZStack
        }
        .padding(.bottom) // Add padding below this section
    }

    /// Displays the Scan/Retake button.
    private var scanButtonSection: some View {
        Button {
            viewModel.checkGearButtonTapped() // Call ViewModel action
        } label: {
            // Read image state from ViewModel
            Label(viewModel.selfieImage == nil ? "Check My Gear (Take Selfie)" : "Retake Selfie",
                  systemImage: "person.crop.square.badge.camera")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .disabled(viewModel.isProcessing) // Disable based on ViewModel state
        .padding(.top)
    }

    /// Displays the detection results or status messages.
    private var resultsSection: some View {
        VStack(alignment: .leading) {
            Divider().padding(.top)
            Text("Detection Results:")
                .font(.headline)

            // Uses ViewModel state to determine what to show
            // Display results ONLY AFTER preview is dismissed AND processing is done
            let shouldShowResults = viewModel.selfieImage != nil && !viewModel.showDetectionPreview && !viewModel.isProcessing

            if let errorMessage = viewModel.detectionErrorMessage {
                 // Show error message if present
                 Text("Error: \(errorMessage)")
                     .foregroundColor(.red)
                     .font(.caption)
                     .frame(minHeight: 100, alignment: .top)
            } else if shouldShowResults && viewModel.detectedObjects.isEmpty {
                 // Show if scan is done but nothing was detected/kept
                 Text("No relevant objects detected.")
                     .foregroundColor(.gray)
                     .font(.caption)
                     .frame(minHeight: 100, alignment: .top)
            } else if shouldShowResults && !viewModel.detectedObjects.isEmpty {
                // Display PPE Check based on ViewModel's detectedObjects
                 VStack(alignment: .leading) {
                     ForEach(requiredGear, id: \.self) { gearItem in
                         // Check if detectedObjects contains a match (case-insensitive)
                         // Use local ppeLabels for the check
                         let isDetected = viewModel.detectedObjects.contains { detObj in
                              self.ppeLabels.contains(detObj.label.lowercased()) &&
                              gearItem.lowercased() == detObj.label.lowercased()
                         } || (gearItem == "Helmet" && viewModel.detectedObjects.contains { $0.label == "sports ball" }) // Fallback

                         HStack {
                             Label(gearItem, systemImage: isDetected ? "checkmark.shield.fill" : "xmark.shield.fill")
                             Text(isDetected ? "Detected" : "Not Detected")
                                 .foregroundColor(isDetected ? .green : .red)
                         }
                     }
                     // Disclosure group for all detected objects
                     DisclosureGroup("All Detected Objects (\(viewModel.detectedObjects.count))") {
                        List {
                             ForEach(viewModel.detectedObjects) { obj in
                                  Text("\(obj.label) (\(String(format: "%.0f%%", obj.confidence * 100)))")
                             }
                        }
                        .font(.caption)
                        .frame(maxHeight: 100) // Limit list height
                        .listStyle(.plain)
                     }
                 }
                 .frame(minHeight: 100, alignment: .top) // Keep consistent height
            } else if viewModel.isProcessing {
                 // Show analyzing text only if preview isn't showing
                  if !viewModel.showDetectionPreview {
                       HStack { Spacer(); Text("Analyzing...").foregroundColor(.gray); Spacer() }
                           .frame(minHeight: 100)
                  } else {
                       Text(" ").frame(minHeight: 100) // Keep space
                  }
            }
            else {
                 // Initial state before scan or if image cleared
                 Text("Scan results will appear here.")
                     .foregroundColor(.gray)
                     .font(.caption)
                     .frame(minHeight: 100, alignment: .top)
            }
        } // End results VStack
    }

    // --- Computed property for drawing PPE boxes (Reads ViewModel, uses local ppeLabels) ---
    private var ppeBoundingBoxes: some View {
        GeometryReader { geometry in
            ForEach(viewModel.detectedObjects) { obj in
                // Check against the LOCAL ppeLabels set defined in this View
                if self.ppeLabels.contains(obj.label.lowercased()) {
                    let viewWidth = geometry.size.width
                    let viewHeight = geometry.size.height
                    // Convert normalized top-left box to view coordinates
                    let rect = CGRect(
                        x: obj.boundingBox.origin.x * viewWidth,
                        y: obj.boundingBox.origin.y * viewHeight,
                        width: obj.boundingBox.width * viewWidth,
                        height: obj.boundingBox.height * viewHeight
                    )
                    Rectangle().path(in: rect).stroke(Color.green, lineWidth: 3)
                }
            }
        }
    }

} // End ProtectiveGearView struct


// MARK: - Preview
#Preview {
    NavigationView {
        ProtectiveGearView()
    }
}
