//
//  ProfileView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 5/27/25.
//

import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import Firebase
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Polyline
import SafariServices

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var tutorialManager: TutorialManager
    @ObservedObject var garageManager = GarageManager.shared
    @StateObject private var viewModel = ProfileViewModel()
    @State private var showPastRoutes = false
    @State private var showFriendsSheet = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    @State private var isUploadingImage = false
    @State private var profileImage: UIImage?
    @State private var showSpotifyLoginSheet = false
    @State private var spotifyProfileImage: UIImage?
    @State private var showDisconnectSpotifyAlert = false
    
    
    
    var body: some View {
        NavigationView {
            VStack {
                // Header with profile image and friends button
                HStack {
                    Spacer()
                    Spacer()
                    // Friends button in top right
                    Button(action: {
                        print("Friends button tapped")
                        showFriendsSheet = true
                    }) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.title2)
                            Text("Friends")
                                .font(.headline)
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.8))
                        .cornerRadius(20)
                    }
                    .padding(.trailing, 20)
                    .padding(.top, 10)
                }
                // Profile Image with tap gesture
                ZStack {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    } else if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.black, lineWidth: 2))
                    } else {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                    }
                    
                    // Camera icon overlay
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "camera.fill")
                                .foregroundColor(.black)
                                .padding(8)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .frame(width: 100, height: 100)
                    
                    if isUploadingImage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.5)
                            .frame(width: 100, height: 100)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(50)
                    }
                }
                .padding(.top, 40)
                .onTapGesture {
                    showImagePicker = true
                }
                .onChange(of: viewModel.profilePictureURL) { _ in
                    loadProfileImage()
                }
                .onChange(of: selectedImage) { newImage in
                    if let newImage = newImage, let userId = authManager.userId {
                        isUploadingImage = true
                        
                        Task {
                            do {
                                // 1. Upload to S3
                                let imageURL = try await uploadImageToS3(
                                    image: newImage,
                                    bucketName: "cartrekk-images"
                                )
                                
                                // 2. Update Firestore
                                if imageURL != "NULL" {
                                    FirestoreManager.shared.updateUserProfilePicture(
                                        userId: userId,
                                        profilePictureURL: imageURL
                                    ) { success in
                                        DispatchQueue.main.async {
                                            isUploadingImage = false
                                            if success {
                                                viewModel.profilePictureURL = imageURL
                                            } else {
                                                // Handle error (could show an alert)
                                                print("Failed to update profile picture in database")
                                            }
                                        }
                                    }
                                } else {
                                    DispatchQueue.main.async {
                                        isUploadingImage = false
                                        // Handle upload failure (could show an alert)
                                        print("Failed to upload image to S3")
                                    }
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    isUploadingImage = false
                                    print("Error uploading profile picture: \(error)")
                                }
                            }
                        }
                    }
                }
                
                
                // Username
                Text(authManager.username ?? "Not found")
                    .font(.title)
                    .bold()
                    .foregroundColor(.black)
                    .padding(.top, 10)

                VStack(spacing: 15) {
                    Text("Total Miles: \(String(format: "%.2f", garageManager.totalMiles)) mi")
                        .font(.headline)
                    
                    //Text("Usable Points: \(String(format: "%.2f", garageManager.usableMiles))")
                    //    .font(.headline)
                    //    .foregroundColor(garageManager.usableMiles >= 25 ? .green : .red)
                    
                    NavigationLink(destination: PastRoutesView()) {
                        ProfileButton(title: "Past Routes", icon: "map")
                    }
                    
                    
                    NavigationLink(destination: GarageView()) {
                        ProfileButton(title: "Garage", icon: "door.garage.closed")
                    }
                    
                    
                    Button (action:{
                        tutorialManager.triggerTutorial()
                    }) {
                        ProfileButton(title: "Tutorial", icon: "questionmark.circle")
                    }
                    
                    Button(action: logout) {
                        ProfileButton(title: "Log Out", icon: "figure.run", color: .red)
                    }
                    Button(action: {
                        if viewModel.isSpotifyConnected {
                            // Show confirmation alert
                            showDisconnectSpotifyAlert = true
                        } else {
                            showSpotifyLoginSheet = true
                        }
                    }) {
                        // Keep your existing button appearance
                        HStack {
                            Image(systemName: viewModel.isSpotifyConnected ? "music.note" : "music.note.list")
                                .foregroundColor(viewModel.isSpotifyConnected ? .green : .white)
                                .imageScale(.large)
                            
                            if viewModel.isSpotifyConnected {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Spotify Connected")
                                        .font(.title3)
                                        .bold()
                                        .foregroundColor(.green)
                                    
                                    if !viewModel.spotifyUsername.isEmpty {
                                        Text(viewModel.spotifyUsername)
                                            .font(.caption)
                                            .foregroundColor(.black)
                                    }
                                }
                            } else {
                                Text("Connect Spotify")
                                    .font(.title3)
                                    .bold()
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.horizontal)
                    }
                    .confirmationDialog(
                        "Disconnect Spotify",
                        isPresented: $showDisconnectSpotifyAlert,
                        titleVisibility: .visible
                    ) {
                        Button("Disconnect", role: .destructive) {
                            disconnectSpotify()
                        }
                        Button("Cancel", role: .cancel) {}
                    }

                }.padding(.top, 30)
                Spacer()
            }
            .sheet(isPresented: $showFriendsSheet) {
               FriendsView()
                   .environmentObject(authManager)
           }
            .sheet(isPresented: $showSpotifyLoginSheet, onDismiss: {
                // Refresh Spotify status when sheet is dismissed
                if let userId = authManager.userId {
                    Task {
                        await viewModel.checkSpotifyConnectionStatus(userId: userId)
                    }
                }
            }) {
                SpotifyLoginView()
                    .environmentObject(authManager)
            }
           .sheet(isPresented: $showImagePicker) {
               ImagePicker(selectedImage: $selectedImage)
           }
            .sheet(isPresented: $showFriendsSheet) {
               FriendsView()
                   .environmentObject(authManager)
           }
            .frame(maxWidth: .infinity)
            .background(Color.white.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
        }
        .onAppear {
            if let userId = authManager.userId {
                Task {
                    await viewModel.loadRoutes(userId: userId)
                    garageManager.fetchTotalMiles(userId: userId)
                    loadProfileImage()
                    await viewModel.loadUserProfile(userId: userId)
                    await viewModel.checkSpotifyConnectionStatus(userId: userId)
                    // Load Spotify image if URL is available
                }
            }
        }
    }
    
    func disconnectSpotify() {
        if let userId = authManager.userId {
            // Remove Spotify connection from Firestore
            FirestoreManager.shared.db.collection("users").document(userId).updateData([
                "spotifyConnected": false,
                "spotifyUsername": FieldValue.delete(),
                "spotifyAccessToken": FieldValue.delete(),
                "spotifyRefreshToken": FieldValue.delete(),
                "spotifyTokenExpiration": FieldValue.delete(),
                "spotifyProfileImageURL": FieldValue.delete()
            ]) { error in
                if let error = error {
                    print("Error disconnecting Spotify: \(error)")
                } else {
                    print("Successfully disconnected Spotify")
                    
                    // Update the view model
                    DispatchQueue.main.async {
                        self.viewModel.isSpotifyConnected = false
                        self.viewModel.spotifyUsername = ""
                    }
                }
            }
        }
    }
    
    private func logout() {
        do {
            try Auth.auth().signOut()
            authManager.isLoggedIn = false
            authManager.userId = nil
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    private func loadProfileImage() {
        guard let profileImageURL = viewModel.profilePictureURL,
              let url = URL(string: profileImageURL) else {
            return
        }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.profileImage = image
                }
            }
        }.resume()
    }
    
}

// MARK: - Profile Button Component
struct ProfileButton: View {
    var title: String
    var icon: String
    var color: Color = .blue
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.black)
                .imageScale(.large)
            
            Text(title)
                .font(.title3)
                .bold()
                .foregroundColor(.black)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(color.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }
}


