//
//  EquipmentInfoView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/15/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

// Ensure Deployment Target is iOS 18.0+

struct EquipmentInfoView: View {

    // Create and keep alive the ViewModel using @StateObject
    @StateObject private var viewModel = EquipmentInfoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { // Add spacing for sections

                // Display the Form Subview, passing the ViewModel
                EquipmentFormView(viewModel: viewModel)

                // Display the Image Capture Subview, passing the ViewModel
                EquipmentImageCaptureView(viewModel: viewModel)

                // Debug Disclosure Group (Reads from ViewModel)
                DisclosureGroup("Raw OCR Results (Debug)") {
                    if viewModel.isProcessing && viewModel.ocrObservations.isEmpty {
                        ProgressView()
                    } else if viewModel.ocrObservations.isEmpty {
                        Text(viewModel.capturedEquipmentImage == nil ? "Scan an image." : "No text detected.")
                            .foregroundColor(.gray)
                            .font(.caption)
                    } else {
                        VStack(alignment: .leading) {
                            // Access ViewModel's properties
                            ForEach(viewModel.ocrObservations, id: \.uuid) { obs in
                                // Assuming RecognizedTextObservation has topCandidates & string
                                Text(obs.topCandidates(1).first?.string ?? "??")
                                    .font(.caption)
                            }
                        }
                    }
                }
                .padding()

                Spacer() // Push content up

            } // End main VStack
        } // End ScrollView
        .navigationTitle("Capture Equipment Info") // Title for this screen
        // --- Sheet Presentation Logic (Managed by ViewModel State) ---

        // 1. Show Camera via Full Screen Cover
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            // Ensure ImagePicker.swift exists and is correct
            ImagePicker(selectedImage: Binding(
                get: { viewModel.capturedEquipmentImage },
                set: { newImage in viewModel.imageCaptured(newImage) } // Call ViewModel action
            ), isFrontCamera: false)
        }

        // 2. Show OCR Preview via Sheet
        .sheet(isPresented: $viewModel.showOcrPreview) {
            if let image = viewModel.capturedEquipmentImage {
                 // Ensure OcrPreviewView.swift exists and is correct
                 OcrPreviewView(
                     image: image,
                     observations: viewModel.ocrObservations, // Use ViewModel data
                     onRetake: viewModel.retakePhoto,         // Call ViewModel action
                     onProceed: viewModel.proceedWithOcrResults // Call ViewModel action
                 )
             } else {
                  Text("Error: Missing image for preview.") // Fallback
                  Button("Dismiss") { viewModel.showOcrPreview = false }.padding()
             }
        }

        // 3. Show Auto-Parse Review via Sheet
        .sheet(isPresented: $viewModel.showAutoParseReview) {
            // Ensure AutoParseReviewView.swift exists and is correct
            AutoParseReviewView(
                isPresented: $viewModel.showAutoParseReview, // Binding to dismiss
                autoParsedData: viewModel.initialAutoParsedData, // Pass parsed data
                onAccept: viewModel.acceptAutoParseAndProceedToAssignment // Pass action
            )
        }

        // 4. Show Field Assignment via Sheet
        .sheet(isPresented: $viewModel.isAssigningFields) {
             if viewModel.currentAssignmentIndex < viewModel.fieldsToAssign.count {
                 let currentField = viewModel.fieldsToAssign[viewModel.currentAssignmentIndex]
                 // Filter list based on ViewModel state
                 let availableOcrStrings = viewModel.allOcrStrings.filter { !viewModel.assignedOcrValues.contains($0) }
                 // Ensure FieldAssignmentView.swift exists and is correct
                 FieldAssignmentView(
                     isPresented: $viewModel.isAssigningFields, // Pass binding
                     allOcrStrings: availableOcrStrings,
                     fieldName: currentField.name,
                     onAssign: viewModel.handleAssignment, // Pass ViewModel method
                     autoParsedData: viewModel.initialAutoParsedData // Pass already parsed data for display
                 )
             }
        }

        // 5. Overlay for Processing Indicator
        .overlay {
            if viewModel.isProcessing {
                // Ensure ProcessingIndicatorView.swift exists
                ProcessingIndicatorView()
            }
        }

    } // End body
} // End EquipmentInfoView


// MARK: - Preview
#Preview {
     NavigationView { // Wrap preview in NavView
          EquipmentInfoView()
     }
}
