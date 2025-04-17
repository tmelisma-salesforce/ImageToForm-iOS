//
//  ProtectiveGearView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import Vision        // Added Vision import here too
import CoreGraphics  // Added CoreGraphics import

struct ProtectiveGearView: View {

    // Create instance of the ViewModel for this view
    @StateObject private var viewModel = ProtectiveGearViewModel()

    // Define required gear list (can be moved to ViewModel if desired)
    let requiredGear = ["Helmet", "Gloves", "Boots"]
    // Define PPE labels expected from the model (lowercase)
    let ppeLabels: Set<String> = ["helmet", "glove", "boot", "safety vest", "safety glasses", "face shield", "sports ball"] // Example

    var body: some View {
        VStack(alignment: .leading) {
            // Required Gear List
            Text("Required Personal Protective Equipment (PPE):")
                .font(.headline)
                .padding(.bottom, 5)
            ForEach(requiredGear, id: \.self) { item in
                Label(item, systemImage: "shield.lefthalf.filled")
            }
            .padding(.leading)
            .padding(.bottom)

            Divider()

            // Selfie Capture Section
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
                        // Read detections from ViewModel for overlay
                        .overlay(ppeBoundingBoxes) // Green boxes for detected PPE
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
                    // Placeholder
                    Text("Take a selfie to check your gear.")
                        .foregroundColor(.gray)
                        .frame(height: 200)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 5).fill(Color(uiColor: .systemGray6)))
                }
            }
            .padding(.bottom)

            // Scan Button - Calls ViewModel action
            Button {
                viewModel.checkGearButtonTapped() // Use ViewModel method
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

            // Results Area - Reads state from ViewModel
            Divider().padding(.top)
            Text("Detection Results:")
                .font(.headline)

            // Check ViewModel state for display logic
            if let errorMessage = viewModel.detectionErrorMessage {
                 Text("Error: \(errorMessage)")
                     .foregroundColor(.red)
                     .font(.caption)
                     .frame(minHeight: 100, alignment: .top)
            } else if viewModel.isProcessing {
                 // Avoid showing analyzing text if preview is shown
                 if !viewModel.showDetectionPreview {
                     HStack { Spacer(); Text("Analyzing...").foregroundColor(.gray); Spacer() }
                         .frame(minHeight: 100)
                 } else {
                     Text(" ").frame(minHeight: 100) // Keep space
                 }
            } else if viewModel.selfieImage != nil && !viewModel.showDetectionPreview && viewModel.detectedObjects.isEmpty {
                 Text("No relevant objects detected.")
                     .foregroundColor(.gray)
                     .frame(minHeight: 100, alignment: .top)
            } else if viewModel.selfieImage != nil && !viewModel.showDetectionPreview && !viewModel.detectedObjects.isEmpty {
                // Display PPE Check based on ViewModel's detectedObjects
                 VStack(alignment: .leading) {
                     ForEach(requiredGear, id: \.self) { gearItem in
                         let isDetected = viewModel.detectedObjects.contains { // Check ViewModel data
                             $0.label.lowercased() == gearItem.lowercased() ||
                             ($0.label == "sports ball" && gearItem == "Helmet") // Example fallback
                         }
                         HStack {
                             Label(gearItem, systemImage: isDetected ? "checkmark.shield.fill" : "xmark.shield.fill")
                             Text(isDetected ? "Detected" : "Not Detected")
                                 .foregroundColor(isDetected ? .green : .red)
                         }
                     }
                     DisclosureGroup("All Detected Objects (\(viewModel.detectedObjects.count))") {
                        List {
                             ForEach(viewModel.detectedObjects) { obj in // Use ViewModel data
                                  Text("\(obj.label) (\(String(format: "%.0f%%", obj.confidence * 100)))")
                             }
                        }
                        .font(.caption)
                        .frame(maxHeight: 100)
                        .listStyle(.plain)
                     }
                 }
                 .frame(minHeight: 100, alignment: .top)
            } else {
                 // Initial state before scan
                 Text("Scan results will appear here.")
                     .foregroundColor(.gray)
                     .font(.caption)
                     .frame(minHeight: 100, alignment: .top)
            }

            Spacer() // Pushes content up

        } // End main VStack
        .padding()
        .navigationTitle("Verify Protective Gear")
        // --- Modifiers read state from ViewModel ---
        .fullScreenCover(isPresented: $viewModel.showFrontCamera) {
            // ImagePicker updates ViewModel via binding created implicitly
            ImagePicker(selectedImage: $viewModel.selfieImage, isFrontCamera: true)
        }
        // Remove .onChange - imageCaptured is called directly via binding/ViewModel method now if needed
        // The ViewModel handles the Task internally when image is set.

         // Sheet for Detection Preview (reads state from ViewModel)
         .sheet(isPresented: $viewModel.showDetectionPreview) {
              if let image = viewModel.selfieImage {
                   ObjectDetectionPreviewView(
                       image: image,
                       detectedObjects: viewModel.detectedObjects, // Pass ViewModel data
                       onRetake: viewModel.retakePhoto, // Call ViewModel action
                       onProceed: viewModel.proceedFromPreview // Call ViewModel action
                   )
              }
         }
         // Overlay for Processing Indicator (reads state from ViewModel)
         .overlay { if viewModel.isProcessing { ProcessingIndicatorView() } }

    } // End body


    // --- Computed property for drawing PPE boxes on main view ---
    // Reads detectedObjects directly from ViewModel
    private var ppeBoundingBoxes: some View {
        GeometryReader { geometry in
            // Access ViewModel's property
            ForEach(viewModel.detectedObjects) { obj in
                // Check against local ppeLabels set
                if ppeLabels.contains(obj.label.lowercased()) {
                    let viewWidth = geometry.size.width
                    let viewHeight = geometry.size.height
                    let rect = CGRect(
                        x: obj.boundingBox.origin.x * viewWidth,
                        y: obj.boundingBox.origin.y * viewHeight,
                        width: obj.boundingBox.width * viewWidth,
                        height: obj.boundingBox.height * viewHeight
                    )
                    Rectangle()
                        .path(in: rect)
                        .stroke(Color.green, lineWidth: 3)
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
