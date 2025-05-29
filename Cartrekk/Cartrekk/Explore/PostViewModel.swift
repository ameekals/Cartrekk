//
//  PostViewModel.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 5/28/25.
//
import SwiftUI


class PostViewModel: ObservableObject {
    @Published var profileImage: UIImage?
    private var imageLoadTask: Task<Void, Never>?
    private let firestoreManager = FirestoreManager.shared
    
    func loadProfilePicture(userId: String) {
        // Cancel any existing task
        imageLoadTask?.cancel()
        
        // Create a new task to load the profile picture
        imageLoadTask = Task {
            do {
                // Use the abstracted method from FirestoreManager
                let image = try await firestoreManager.getUserProfileImage(userId: userId)
                
                // Update the UI on the main thread
                if !Task.isCancelled {
                    await MainActor.run {
                        self.profileImage = image
                    }
                }
            } catch {
                print("Error loading profile picture: \(error)")
            }
        }
    }
    
    deinit {
        imageLoadTask?.cancel()
    }
    
}

