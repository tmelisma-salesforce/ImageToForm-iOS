import SwiftUI

// Note: Requires iOS 18.0+ for the new Swift-only Vision API used in ViewModel

// MARK: - Main View
struct ProtectiveGearView: View {

    // Use the corrected ViewModel
    @StateObject private var viewModel = ProtectiveGearViewModel()
    @State private var showingCameraOptions = false

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Verify Required Protective Gear:")
                    .font(.title)
                    .fontWeight(.medium)
                    .padding(.bottom)

                ChecklistView(
                    isHelmetChecked: viewModel.isHelmetChecked,
                    isGlovesChecked: viewModel.isGlovesChecked,
                    isBootsChecked: viewModel.isBootsChecked
                )

                Spacer()

                CheckGearButton(
                    isProcessing: viewModel.isProcessing,
                    action: {
                        showingCameraOptions = true
                    }
                )
                .padding(.bottom)

            } // End main VStack
            .padding()
            .navigationTitle("Verify Protective Gear")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog("Select Camera", isPresented: $showingCameraOptions, titleVisibility: .visible) {
                Button("Selfie (Check Helmet/Gloves)") { viewModel.initiateScan(useFrontCamera: true) }
                Button("Rear Camera (Check Boots/Feet)") { viewModel.initiateScan(useFrontCamera: false) }
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
             // --- UPDATED: Pass lastScanWasFrontCamera to sheet content ---
             .sheet(isPresented: $viewModel.showDetectionPreview) {
                  if let image = viewModel.selfieImage {
                       ObjectDetectionPreviewView(
                           image: image,
                           detectedObjects: viewModel.objectsForPreview,
                           previewMessage: viewModel.previewMessage,
                           // Pass the flag indicating if the *last completed scan* used the front camera
                           isFrontCameraImage: viewModel.lastScanWasFrontCamera,
                           onRetake: viewModel.retakePhoto,
                           onProceed: viewModel.proceedFromPreview
                       )
                  }
             }
             // --- END UPDATE ---
             .overlay {
                 if viewModel.isProcessing {
                      ProcessingIndicatorView()
                 }
             }
             .alert("Insufficient Gear", isPresented: $viewModel.showFlipFlopErrorAlert) {
                  Button("OK", role: .cancel) { }
             } message: {
                  Text("Flip-flops were detected. Boots are required for proper foot protection.")
             }

        } // End NavigationView
    } // End body
} // End ProtectiveGearView struct


// MARK: - Child View: Checklist
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

// MARK: - Child View: Checklist Item
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


// MARK: - Preview
// Re-enable preview if build hangs are resolved, or keep commented out.
/*
#Preview {
    NavigationView {
        ProtectiveGearView()
    }
}
*/

