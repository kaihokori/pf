//
//  ImagePickerComponent.swift
//  Trackerio
//
//  Created by Kyle Graham on 1/12/2025.
//

import SwiftUI

struct ImagePickerComponent: UIViewControllerRepresentable {
    var sourceType: UIImagePickerController.SourceType
    var completion: (Data?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let controller = UIImagePickerController()
        controller.sourceType = sourceType
        controller.delegate = context.coordinator
        controller.allowsEditing = false
        return controller
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ImagePickerComponent

        init(parent: ImagePickerComponent) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = (info[.originalImage] as? UIImage)
            let data = image?.jpegData(compressionQuality: 0.85)
            parent.completion(data)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.completion(nil)
            picker.dismiss(animated: true)
        }
    }
}
