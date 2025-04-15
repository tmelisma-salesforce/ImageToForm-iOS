//
//  ImagePicker.swift
//  ImageToFormPOC
//
//  Created by Toni Melisma on 4/14/25.
//  Copyright © 2025 Toni Melisma. All rights reserved.
//

import SwiftUI
import UIKit
// We don't need to import Vision here, as processing is handled elsewhere now

// This struct wraps the UIKit's UIImagePickerController so we can use it in SwiftUI
struct ImagePicker: UIViewControllerRepresentable {

    // MARK: - Properties

    // Binding: Connects this view's selectedImage back to the @State variable in ContentView
    @Binding var selectedImage: UIImage?

    // Environment property to allow dismissing this modal view
    @Environment(\.presentationMode) var presentationMode

    // MARK: - UIViewControllerRepresentable Methods

    // Creates the Coordinator class instance (defined below)
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Creates the actual UIImagePickerController instance when SwiftUI needs it
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Set the Coordinator class as the delegate to receive user actions
        picker.delegate = context.coordinator
        // Check if the physical camera is available on the device
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            picker.sourceType = .camera // Use camera if available
        } else {
            // Fallback to photo library if no camera (e.g., on Simulator)
            print("INFO: Camera not available, using photo library as fallback.")
            picker.sourceType = .photoLibrary
        }
        return picker
    }

    // This method is required by the protocol, but we don't need to update
    // the UIImagePickerController from SwiftUI in this simple case.
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // No update actions needed here for the POC
    }

    // MARK: - Coordinator Class

    // Coordinator acts as the delegate for the UIImagePickerController
    // It handles events like image selection or cancellation.
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let parent: ImagePicker // Holds a reference back to the ImagePicker struct

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        // Called when the user has taken/selected a photo and confirmed
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            print("Image picked by user.") // Log for debugging
            // Try to get the original image selected by the user
            if let uiImage = info[.originalImage] as? UIImage {
                // Update the @State variable back in ContentView via the @Binding
                parent.selectedImage = uiImage
                print("Selected image set in ContentView.")
            } else {
                print("Error: Could not retrieve the original image.")
            }
            // Dismiss the picker view controller
            parent.presentationMode.wrappedValue.dismiss()
        }

        // Called when the user taps the "Cancel" button
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            print("Image picker cancelled by user.") // Log for debugging
            // Dismiss the picker view controller
            parent.presentationMode.wrappedValue.dismiss()
        }
    } // End of Coordinator Class

} // End of ImagePicker Struct
