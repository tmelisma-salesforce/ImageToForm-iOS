//
//  ImagePicker.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import UIKit
// No Vision needed in this file

struct ImagePicker: UIViewControllerRepresentable {

    // MARK: - Properties
    @Binding var selectedImage: UIImage?
    let isFrontCamera: Bool // NEW: Flag to indicate desired camera

    @Environment(\.presentationMode) var presentationMode

    // MARK: - Coordinator
    // Coordinator remains the same as before
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker
        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("Image picked by user.")
            if let uiImage = info[.originalImage] as? UIImage {
                parent.selectedImage = uiImage
                print("Selected image set.")
                // Processing is handled by the calling view's .onChange
            } else {
                print("Error: Could not retrieve the original image.")
            }
            parent.presentationMode.wrappedValue.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("Image picker cancelled by user.")
            parent.presentationMode.wrappedValue.dismiss()
        }
    } // End Coordinator

    // MARK: - Representable Methods (UPDATED makeUIViewController)

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator

        // --- UPDATED CAMERA LOGIC ---
        // Check if camera source is available at all
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            // If front camera requested AND available, use it
            if self.isFrontCamera && UIImagePickerController.isCameraDeviceAvailable(.front) {
                print("INFO: Using Front Camera.")
                picker.sourceType = .camera
                picker.cameraDevice = .front
            } else if UIImagePickerController.isCameraDeviceAvailable(.rear) {
                // Otherwise, use rear camera if available (and front wasn't requested/available)
                print("INFO: Using Rear Camera.")
                picker.sourceType = .camera
                picker.cameraDevice = .rear // Default to rear if available
            } else {
                // Fallback if even rear camera isn't available (unlikely on iPhone)
                 print("INFO: Camera source selected, but no specific device available. Using default.")
                 picker.sourceType = .camera
            }
        } else {
            // Fallback to photo library if camera source unavailable (e.g., Simulator)
            print("INFO: Camera not available, using photo library.")
            picker.sourceType = .photoLibrary
        }
        // --- END UPDATED CAMERA LOGIC ---

        return picker
    }

    // updateUIViewController remains empty
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

} // End ImagePicker
