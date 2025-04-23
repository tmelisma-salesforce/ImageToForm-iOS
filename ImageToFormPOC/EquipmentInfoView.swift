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
        // Use a NavigationStack to enable programmatic navigation
        NavigationStack {
            // Use a VStack for overall layout: Content + Footer
            VStack(spacing: 0) { // No spacing between content and footer

                // Scrollable Form Content
                ScrollView {
                    // Padding applied inside ScrollView
                    VStack(alignment: .leading, spacing: 20) {
                        EquipmentFormView(viewModel: viewModel)
                            .disabled(viewModel.isProcessing || viewModel.isAssigningFields)

                        // Add Spacer to push form to top if content is short
                        Spacer(minLength: 20) // Adjust minLength as needed

                    } // End inner VStack
                    .padding() // Padding around the form content
                    // Ensure the content pushes against the ScrollView bounds
                    .frame(maxWidth: .infinity)

                } // End ScrollView

                // --- Add Spacer BETWEEN ScrollView and Footer ---
                // This pushes the footer to the bottom IF ScrollView content is short
                Spacer()
                // --- End Spacer ---

                // --- Footer Area ---
                HStack(spacing: 15) {
                    // Initiate Scan Button
                    Button {
                        print("Scan/Rescan button tapped. Calling initiateScan.")
                        viewModel.initiateScan()
                    } label: {
                        Label(viewModel.capturedEquipmentImage == nil && viewModel.make.isEmpty ? "Scan Label" : "Rescan Label", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(viewModel.isProcessing || viewModel.isAssigningFields)

                    // Confirm Button
                    Button("Confirm") {
                        viewModel.confirmEquipmentInfo()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(!viewModel.assignmentFlowComplete || viewModel.isProcessing || viewModel.isAssigningFields)

                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(.bar) // Use a bar background for visual separation
                // --- End Footer Area ---

            } // End outer VStack
            .navigationTitle("Capture Equipment Info")
            .navigationBarTitleDisplayMode(.inline)

            // --- Navigation Link for Confirmation Destination ---
            .navigationDestination(isPresented: $viewModel.showConfirmationDestination) {
                 ManualView() // Replace with actual destination view later
            }

            // --- Sheet Presentation Modifiers ---
            // Apply modifiers to the content VStack

            // 1. Show Camera via Full Screen Cover
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                let _ = print("Presenting fullScreenCover. showCamera is \(viewModel.showCamera)")
                // Use direct binding and .onChange modifier below
                ImagePicker(selectedImage: $viewModel.capturedEquipmentImage, isFrontCamera: false)
             }
            // --- NEW: Use .onChange to trigger image processing ---
            .onChange(of: viewModel.capturedEquipmentImage) { _, newImage in
                 if let image = newImage, !viewModel.isProcessing { // Prevent processing if already processing
                      viewModel.imageCaptured(image)
                 }
            }
            // --- END NEW ---

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
                          onAssign: viewModel.handleAssignment
                      )
                  }
             }
            // 5. Show Manual View (Triggered by navigationDestination now)
            // .sheet(isPresented: $viewModel.showManualView) { ManualView() }

            // 6. Overlay for Processing Indicator
            .overlay {
                 if viewModel.isProcessing {
                      ProcessingIndicatorView()
                  }
             }
            // --- End Sheet Presentation Modifiers ---

        } // End NavigationStack
    } // End body
} // End EquipmentInfoView


// MARK: - Preview
#Preview("Initial State") {
     NavigationStack {
          EquipmentInfoView()
     }
}

