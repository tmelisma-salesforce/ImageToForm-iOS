import SwiftUI

// Note: Requires iOS 18.0+ for the new Swift-only Vision API used in ViewModel

// MARK: - Main View
struct ProtectiveGearView: View {

    // Use the corrected ViewModel (assuming previous fixes are applied)
    @StateObject private var viewModel = ProtectiveGearViewModel()
    @State private var showingCameraOptions = false // This state is now relevant again

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Verify Required Protective Gear:")
                    .font(.title)
                    .fontWeight(.medium)
                    .padding(.bottom)

                // ChecklistView is uncommented
                ChecklistView(
                    isHelmetChecked: viewModel.isHelmetChecked,
                    isGlovesChecked: viewModel.isGlovesChecked,
                    isBootsChecked: viewModel.isBootsChecked
                )

                Spacer() // Pushes button to the bottom

                // CheckGearButton is uncommented
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

            // .confirmationDialog is uncommented
            .confirmationDialog("Select Camera", isPresented: $showingCameraOptions, titleVisibility: .visible) {
                Button("Selfie (Check Helmet/Gloves)") { viewModel.initiateScan(useFrontCamera: true) }
                Button("Rear Camera (Check Boots/Feet)") { viewModel.initiateScan(useFrontCamera: false) }
                Button("Cancel", role: .cancel) { }
            }

            // .fullScreenCover is uncommented
            .fullScreenCover(isPresented: $viewModel.showCamera) {
                ImagePicker(selectedImage: $viewModel.selfieImage, isFrontCamera: viewModel.isFrontCamera)
            }

            // .onChange is uncommented
             .onChange(of: viewModel.selfieImage) { _, newImage in
                  if let image = newImage {
                       viewModel.imageCaptured(image)
                  } else {
                       print("ProtectiveGearView: onChange detected selfieImage became nil.")
                  }
             }

             // .sheet is uncommented
             .sheet(isPresented: $viewModel.showDetectionPreview) {
                  // Ensure the preview view gets the correct data from the ViewModel
                  if let image = viewModel.selfieImage {
                       ObjectDetectionPreviewView(
                           image: image,
                           detectedObjects: viewModel.objectsForPreview, // Use filtered list
                           previewMessage: viewModel.previewMessage,     // Pass the message
                           onRetake: viewModel.retakePhoto,      // Pass method reference
                           onProceed: viewModel.proceedFromPreview // Pass method reference
                       )
                  }
             }

             // .overlay is uncommented
             .overlay {
                 if viewModel.isProcessing {
                      ProcessingIndicatorView()
                 }
             }

             // .alert is uncommented
             .alert("Insufficient Gear", isPresented: $viewModel.showFlipFlopErrorAlert) { // Use correct flag
                  Button("OK", role: .cancel) { }
             } message: {
                  Text("Flip-flops were detected. Boots are required for proper foot protection.")
             }

        } // End NavigationView
    } // End body
} // End ProtectiveGearView struct


// MARK: - Child View: Checklist (Keep definition)
struct ChecklistView: View {
    let isHelmetChecked: Bool
    let isGlovesChecked: Bool
    let isBootsChecked: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ChecklistItem(label: "Helmet", isChecked: isHelmetChecked)
            ChecklistItem(label: "Gloves", isChecked: isGlovesChecked)
            ChecklistItem(label: "Boots", isChecked: isBootsChecked)
        }
    }
}

// MARK: - Child View: Checklist Item (Keep definition)
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

// MARK: - Child View: Check Gear Button (Keep definition)
struct CheckGearButton: View {
    let isProcessing: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label("Check My Gear", systemImage: "camera.viewfinder")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(isProcessing)
    }
}


// MARK: - Preview (Reintroduced)
// --- Debug: Reintroduce #Preview ---
#Preview {
    NavigationView {
        // Using the default initializer which should be fine if model loading is handled robustly
        ProtectiveGearView()
    }
}
// --- End Reintroduce #Preview ---

