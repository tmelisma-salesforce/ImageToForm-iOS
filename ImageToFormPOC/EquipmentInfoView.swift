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

    // Use @StateObject for the ViewModel
    @StateObject private var viewModel = EquipmentInfoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // Form Subview
                EquipmentFormView(viewModel: viewModel)

                // Image Capture Subview
                EquipmentImageCaptureView(viewModel: viewModel)

                // Debug Disclosure Group
                DisclosureGroup("Raw OCR Results (Debug)") {
                    if viewModel.isProcessing && viewModel.ocrObservations.isEmpty { ProgressView() }
                    else if viewModel.ocrObservations.isEmpty { Text(viewModel.capturedEquipmentImage == nil ? "Scan an image." : "No text detected.").foregroundColor(.gray).font(.caption) }
                    else { VStack(alignment: .leading) { ForEach(viewModel.ocrObservations, id: \.uuid) { obs in Text(obs.topCandidates(1).first?.string ?? "??").font(.caption) } } }
                }
                .padding()

                Spacer()

            } // End main VStack
        } // End ScrollView
        .navigationTitle("Capture Equipment Info")
        // --- Sheet Presentation Logic ---

        // 1. Show OCR Preview via Sheet
        .sheet(isPresented: $viewModel.showOcrPreview) {
            if let image = viewModel.capturedEquipmentImage {
                // Ensure OcrPreviewView.swift exists and is correct
                OcrPreviewView(
                    image: image,
                    observations: viewModel.ocrObservations,
                    onRetake: viewModel.retakePhoto,
                    onProceed: viewModel.proceedWithOcrResults
                )
            } else { Text("Error: Missing image for preview.").padding() }
        }

        // 2. Show Field Assignment via Sheet
        .sheet(isPresented: $viewModel.isAssigningFields) {
             if viewModel.currentAssignmentIndex < viewModel.fieldsToAssign.count {
                 let currentField = viewModel.fieldsToAssign[viewModel.currentAssignmentIndex]
                 let availableOcrStrings = viewModel.allOcrStrings.filter { !viewModel.assignedOcrValues.contains($0) }
                 // Ensure FieldAssignmentView.swift exists and is correct
                 FieldAssignmentView(
                     isPresented: $viewModel.isAssigningFields, // Use direct binding
                     allOcrStrings: availableOcrStrings,
                     fieldName: currentField.name,
                     onAssign: viewModel.handleAssignment,
                     autoParsedData: viewModel.initialAutoParsedData
                 )
             }
        }

        // 3. Show Camera via Full Screen Cover
        .fullScreenCover(isPresented: $viewModel.showCamera) {
            // Explicit Binding passes value AND triggers ViewModel's imageCaptured on set
            ImagePicker(selectedImage: Binding(
                get: { viewModel.capturedEquipmentImage },
                set: { newImage in viewModel.imageCaptured(newImage) }
            ), isFrontCamera: false)
            // Ignore .ignoresSafeArea() if causing layout issues, safe area handled by default
            // .ignoresSafeArea()
        }

        // --- REMOVED onChange Modifier ---
        // .onChange(of: viewModel.capturedEquipmentImage) { ... } // DELETE THIS ENTIRE MODIFIER

        // 4. Overlay for Processing Indicator
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
     NavigationView {
          EquipmentInfoView()
     }
}
