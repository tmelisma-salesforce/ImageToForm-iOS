//
//  EquipmentImageCaptureView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct EquipmentImageCaptureView: View {
    // Use @ObservedObject for the shared view model
    @ObservedObject var viewModel: EquipmentInfoViewModel

    var body: some View {
        VStack(alignment: .leading) {
            Text("Equipment Label Photo:")
                .font(.headline)

            if let image = viewModel.capturedEquipmentImage {
                Image(uiImage: image)
                    .resizable().scaledToFit().frame(maxHeight: 200)
                    .overlay(alignment: .topTrailing) {
                        // Button calls ViewModel function to reset
                        Button {
                            viewModel.resetScanState(clearImage: true) // Call ViewModel method
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .background(Color.white.opacity(0.8))
                                .clipShape(Circle())
                                .padding(5)
                        }
                    }
            } else {
                Text("No photo captured yet.")
                    .foregroundColor(.gray).frame(height: 100)
                    .frame(maxWidth: .infinity)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color(uiColor: .systemGray6)))
            }

            Button {
                // Call ViewModel function to initiate scan
                viewModel.initiateScan()
            } label: {
                Label(viewModel.capturedEquipmentImage == nil ? "Scan Equipment Label" : "Rescan Equipment Label",
                      systemImage: "camera.fill")
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity) // Center button if VStack alignment is center
            .disabled(viewModel.isProcessing || viewModel.isAssigningFields) // Disable based on ViewModel state
        }
        .padding(.horizontal) // Add padding to the whole section
    }
}

#Preview {
    EquipmentImageCaptureView(viewModel: EquipmentInfoViewModel())
        .padding()
}
