//
//  PastRoutesViewModel.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 6/3/25.
//

import SwiftUI

import CoreLocation
import FirebaseAuth
import Firebase
import FirebaseFirestore



// MARK: - Profile View Model
class ProfileViewModel: ObservableObject {
    @Published var routes: [FirestoreManager.fb_Route] = []
    @Published var profilePictureURL: String?
    private let db = FirestoreManager()
    @Published var isSpotifyConnected: Bool = false
    @Published var spotifyUsername: String = ""
    
    init() {
        // Set up notification center observer for Spotify connection changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpotifyConnectionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let connected = notification.userInfo?["connected"] as? Bool, connected {
                if let userId = Auth.auth().currentUser?.uid {
                    Task {
                        await self?.checkSpotifyConnectionStatus(userId: userId)
                    }
                }
            }
        }
    }
    
    
    @MainActor
    func loadRoutes(userId: String) async {
        let routes = await withCheckedContinuation { continuation in
            db.getRoutesForUser(userId: userId) { routes in
                let sortedRoutes = (routes ?? []).sorted(by: { $0.createdAt > $1.createdAt })
                continuation.resume(returning: sortedRoutes)
            }
        }
        
        self.routes = routes
    }
    // Add this function to handle route deletion
    @MainActor
    func deleteRoute(routeId: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            db.deleteRoute(routeId: routeId) { success in
                continuation.resume(returning: success)
            }
        }
    }
    
    func checkSpotifyConnectionStatus(userId: String) async {
        do {
            let document = try await FirestoreManager.shared.db.collection("users").document(userId).getDocument()
            if let data = document.data() {
                let isConnected = data["spotifyConnected"] as? Bool ?? false
                let username = data["spotifyUsername"] as? String ?? ""
                
                DispatchQueue.main.async {
                    self.isSpotifyConnected = isConnected
                    self.spotifyUsername = username
                }
            }
        } catch {
            print("Error checking Spotify status: \(error)")
        }
    }
    
    func togglePublicStatus(routeId: String) async {
        print("Attempting to toggle in Firestore")
        let db = Firestore.firestore()
        do {
            // First get current status
            let doc = try await db.collection("routes").document(routeId).getDocument()
            let isCurrentlyPublic = doc.data()?["public"] as? Bool ?? false
            
            // Toggle it
            try await db.collection("routes").document(routeId).updateData([
                "public": !isCurrentlyPublic
            ])
            print("Successfully toggled in Firestore from \(isCurrentlyPublic) to \(!isCurrentlyPublic)")
        } catch {
            print("Error toggling public status: \(error)")
        }
    }
    
    func loadCommentsForRoute(routeId: String) async -> [Comment] {
        return await withCheckedContinuation { continuation in
            db.getCommentsForRoute(routeId: routeId) { comments in
                continuation.resume(returning: comments ?? [])
            }
        }
    }
    
    func loadUserProfile(userId: String) async {
        let db = Firestore.firestore()
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if let data = document.data(), let profileURL = data["profilePictureURL"] as? String {
                DispatchQueue.main.async {
                    self.profilePictureURL = profileURL
                }
            }
        } catch {
            print("Error loading user profile: (error)")
        }
    }
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) private var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
