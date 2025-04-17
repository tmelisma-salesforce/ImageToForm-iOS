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

                // --- NEW: Conditional Show Manual Button ---
                // Visible only after assignment completes successfully
                if viewModel.showManualButton {
                    Button {
                        viewModel.displayManual() // Call ViewModel action
                    } label: {
                        // Use Label for icon + text
                        Label("Show Equipment Manual", systemImage: "book.closed")
                            .frame(maxWidth: .infinity) // Make button wide
                    }
                    .buttonStyle(.bordered) // Use bordered style
                    .padding(.horizontal) // Add padding
                    .padding(.top) // Add padding above the button
                }
                // --- End Show Manual Button ---


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
                            ForEach(viewModel.ocrObservations, id: \.uuid) { obs in
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
            ImagePicker(selectedImage: Binding(
                get: { viewModel.capturedEquipmentImage },
                set: { newImage in viewModel.imageCaptured(newImage) }
            ), isFrontCamera: false)
        }

        // 2. Show OCR Preview via Sheet
        .sheet(isPresented: $viewModel.showOcrPreview) {
            if let image = viewModel.capturedEquipmentImage {
                 OcrPreviewView(
                     image: image,
                     observations: viewModel.ocrObservations,
                     onRetake: viewModel.retakePhoto,
                     onProceed: viewModel.proceedWithOcrResults
                 )
             }
        }

        // 3. Show Auto-Parse Review via Sheet
        .sheet(isPresented: $viewModel.showAutoParseReview) {
            AutoParseReviewView(
                isPresented: $viewModel.showAutoParseReview,
                autoParsedData: viewModel.initialAutoParsedData,
                onAccept: viewModel.acceptAutoParseAndProceedToAssignment
            )
        }

        // 4. Show Field Assignment via Sheet
        .sheet(isPresented: $viewModel.isAssigningFields) {
             if viewModel.currentAssignmentIndex < viewModel.fieldsToAssign.count {
                 let currentField = viewModel.fieldsToAssign[viewModel.currentAssignmentIndex]
                 let availableOcrStrings = viewModel.allOcrStrings.filter { !viewModel.assignedOcrValues.contains($0) }
                 FieldAssignmentView(
                     isPresented: $viewModel.isAssigningFields,
                     allOcrStrings: availableOcrStrings,
                     fieldName: currentField.name,
                     onAssign: viewModel.handleAssignment,
                     autoParsedData: viewModel.initialAutoParsedData // Pass auto-parsed for display
                 )
             }
        }

        // --- NEW: Sheet for Manual View ---
        // 5. Show Manual View
        .sheet(isPresented: $viewModel.showManualView) {
            // Ensure ManualView.swift exists
            ManualView()
        }
        // --- End Manual View Sheet ---


        // 6. Overlay for Processing Indicator
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
