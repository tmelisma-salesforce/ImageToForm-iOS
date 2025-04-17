//
//  ManualView.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/16/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI

struct ManualView: View {
    // Environment variable to dismiss the presented sheet
    @Environment(\.dismiss) var dismiss

    // Placeholder text
    let manualText = """
    TITANAIR INDUSTRIES - Model TAC-4500X - Operations Manual

    Section 1: Safety Precautions
    -----------------------------
    1.1 Disconnect all power sources before performing maintenance. Voltage: 460V, Amperage: 32A.
    1.2 Ensure proper grounding according to local codes.
    1.3 Maintain minimum clearances as specified on the unit label.
    1.4 Operating Pressure: 175 PSI Max. Do not exceed.

    Section 2: Installation
    -----------------------
    2.1 Refer to installation diagram P/N 554-2B.
    2.2 Ensure adequate airflow around the unit.
    2.3 Connect ductwork securely, sealing all joints.
    2.4 Electrical connections must be performed by qualified personnel only.

    Section 3: Operation
    --------------------
    3.1 Set thermostat to desired temperature.
    3.2 Monitor system pressure gauges during initial startup.
    3.3 For optimal performance, replace air filters regularly (monthly recommended).

    Section 4: Maintenance
    ----------------------
    4.1 Monthly: Inspect and clean/replace air filters.
    4.2 Annually: Inspect fan motor and belts. Check refrigerant charge (requires certified technician). Clean evaporator and condenser coils. Check electrical connections for tightness. Lubricate motor bearings if applicable.

    Section 5: Troubleshooting
    --------------------------
    5.1 Unit does not start: Check circuit breaker, thermostat settings, safety switches.
    5.2 Insufficient cooling/heating: Check air filters, refrigerant charge, ductwork blockages.
    5.3 Unusual noise: Check fan blades, motor bearings, loose panels.

    Manufactured Date: Refer to unit serial number plate. For service, provide Model No. and Serial No.
    Warranty information available online.

    --- END OF DOCUMENT ---
    """

    var body: some View {
        NavigationView {
            ScrollView {
                Text(manualText)
                    .font(.system(.body, design: .monospaced)) // Use monospaced for manual feel
                    .padding()
            }
            .navigationTitle("Equipment Manual")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { // Use confirmation placement
                    Button("Done") {
                        dismiss() // Use dismiss environment action
                    }
                }
            }
        }
    }
}

#Preview {
    ManualView()
}
