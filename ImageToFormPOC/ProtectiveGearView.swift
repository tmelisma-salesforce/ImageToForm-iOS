import SwiftUI

// Note: Requires iOS 18.0+ for the new Swift-only Vision API used in ViewModel

// MARK: - Main View
struct ProtectiveGearView: View {

    @StateObject private var viewModel = ProtectiveGearViewModel()
    @State private var showingCameraOptions = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Verify Required Protective Gear:")
                    .font(.title)
                    .fontWeight(.medium)
                    .padding(.bottom)

                // Instantiate ChecklistView, passing necessary state
                ChecklistView(
                    isHelmetChecked: viewModel.isHelmetChecked,
                    isGlovesChecked: viewModel.isGlovesChecked,
                    isBootsChecked: viewModel.isBootsChecked
                )

                Spacer() // Pushes button to the bottom

                // Instantiate CheckGearButton, passing state and action closure
                CheckGearButton(
                    isProcessing: viewModel.isProcessing,
                    action: {
                        showingCameraOptions = true // Show camera selection
                    }
                )
                .padding(.bottom)

            } // End main VStack
            .padding() // Overall padding
            .navigationTitle("Verify Protective Gear")
            .navigationBarTitleDisplayMode(.inline)
            // --- Modifiers applied to the top-level content ---
            .confirmationDialog("Select Camera", isPresented: $showingCameraOptions, titleVisibility: .visible) {
                // Actions call viewModel methods directly from this scope
                Button("Selfie (Check Helmet/Gloves)") {
                    viewModel.initiateScan(useFrontCamera: true)
                }
                Button("Rear Camera (Check Boots/Feet)") {
                    viewModel.initiateScan(useFrontCamera: false)
                }
                Button("Cancel", role: .cancel) { }
            }
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                ImagePicker(selectedImage: $viewModel.selfieImage, isFrontCamera: viewModel.isFrontCamera)
            }
             .onChange(of: viewModel.selfieImage) { _, newImage in
                  if let image = newImage {
                       viewModel.imageCaptured(image)
                  } else {
                       print("ProtectiveGearView: onChange detected selfieImage became nil.")
                  }
             }
             .sheet(isPresented: $viewModel.showDetectionPreview) {
                  if let image = viewModel.selfieImage {
                       ObjectDetectionPreviewView(
                           image: image,
                           detectedObjects: viewModel.detectedObjects, // Pass filtered data
                           onRetake: viewModel.retakePhoto,      // Pass method reference
                           onProceed: viewModel.proceedFromPreview // Pass method reference
                       )
                  }
             }
             .overlay {
                 if viewModel.isProcessing {
                      ProcessingIndicatorView()
                  }
             }
             .alert("Insufficient Gear", isPresented: $viewModel.showFlipFlopError) {
                  Button("OK", role: .cancel) { }
             } message: {
                  Text("Flip-flops were detected. Boots are required for proper foot protection.")
             }
        } // End NavigationView
    } // End body
} // End ProtectiveGearView struct


// MARK: - Child View: Checklist
struct ChecklistView: View {
    // Receives data as simple properties
    let isHelmetChecked: Bool
    let isGlovesChecked: Bool
    let isBootsChecked: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) { // Use VStack for layout if needed
            ChecklistItem(label: "Helmet", isChecked: isHelmetChecked)
            ChecklistItem(label: "Gloves", isChecked: isGlovesChecked)
            ChecklistItem(label: "Boots", isChecked: isBootsChecked)
        }
    }
}

// MARK: - Child View: Checklist Item (Unchanged)
struct ChecklistItem: View {
    let label: String
    let isChecked: Bool

    var body: some View {
        HStack {
            Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                .foregroundColor(isChecked ? .green : .secondary)
                .font(.title)
            Text(label)
                .font(.title2)
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Child View: Check Gear Button
struct CheckGearButton: View {
    let isProcessing: Bool
    let action: () -> Void // Action closure

    var body: some View {
        Button(action: action) { // Execute the closure on tap
            Label("Check My Gear", systemImage: "camera.viewfinder")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isProcessing)
    }
}


// MARK: - Preview
#Preview {
    NavigationView {
        ProtectiveGearView()
    }
}
