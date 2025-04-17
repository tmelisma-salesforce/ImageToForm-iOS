//
//  EquipmentFormView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct EquipmentFormView: View {
    // Use @ObservedObject for a view model passed in
    @ObservedObject var viewModel: EquipmentInfoViewModel

    // State to control calculated height
    @State private var formHeight: CGFloat = 400 // Default or calculate dynamically

    var body: some View {
        Form {
            Section("Equipment Details") {
                TextField("Make", text: $viewModel.make)
                TextField("Model", text: $viewModel.model)
                TextField("Serial Number", text: $viewModel.serialNumber)
                    .keyboardType(.asciiCapable).autocapitalization(.allCharacters)
                TextField("Manufacturing Date (YYYY-MM)", text: $viewModel.manufacturingDateString)
                    .keyboardType(.numbersAndPunctuation)
            }
            Section("Specifications") {
                TextField("Voltage (e.g., 460V)", text: $viewModel.voltageString)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Amps (e.g., 32A)", text: $viewModel.ampsString)
                    .keyboardType(.numbersAndPunctuation)
                TextField("Pressure (e.g., 175PSI)", text: $viewModel.pressureString)
                    .keyboardType(.numbersAndPunctuation)
            }
        }
        // Apply height calculation (can be refined)
        .frame(height: calculateFormHeight())
        // Disable form while processing or assigning fields in parent
        .disabled(viewModel.isProcessing || viewModel.isAssigningFields)
    }

    /// Helper to calculate form height
    private func calculateFormHeight() -> CGFloat {
        let rowCount = 7; let rowHeightEstimate: CGFloat = 55
        return CGFloat(rowCount) * rowHeightEstimate
    }
}

// Preview requires providing a dummy ViewModel
#Preview {
    EquipmentFormView(viewModel: EquipmentInfoViewModel())
}
