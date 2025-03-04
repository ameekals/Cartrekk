//
//  ContentView.swift
//  Cartrekk
//
//  Created by Ameek Singh on 1/18/25.
// test
import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import Firebase
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Polyline

// MARK: - Content View

struct ContentView: View {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var tutorialManager = TutorialManager()
    @State private var email: String = ""
    @State private var password: String = ""
    
    var body: some View {
        if authManager.isLoggedIn {
            if authManager.needsUsername {
                UsernameSetupView(onComplete: {
                    // Always show tutorial after username setup
                    tutorialManager.triggerTutorial()
                })
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
            } else if tutorialManager.showTutorial {
                TutorialView(onComplete: {
                    // Only save tutorial as shown if it wasn't triggered manually
                    if !UserDefaults.standard.bool(forKey: "tutorialShown") {
                        UserDefaults.standard.set(true, forKey: "tutorialShown")
                    }
                    tutorialManager.showTutorial = false
                })
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
            } else {
                MainAppView()
                    .environmentObject(authManager)
                    .environmentObject(tutorialManager) // Pass tutorial manager
                    .preferredColorScheme(.dark)
            }
        } else {
            LoginView(email: $email, password: $password)
                .environmentObject(authManager)
                .preferredColorScheme(.dark)
        }
    }
    
    func onAppear() {
        // Initial check - only show tutorial automatically on first launch
        if authManager.isLoggedIn && !authManager.needsUsername && !UserDefaults.standard.bool(forKey: "tutorialShown") {
            tutorialManager.showTutorial = true
        }
    }
}

// MARK: - Auth Manager



class AuthenticationManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userId: String? = nil
    @Published var username: String? = nil
    @Published var needsUsername: Bool = false
    
    private let firebaseManager = FirestoreManager()  // Assuming this is your Firebase manager class
    
    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = user != nil
                self?.userId = user?.uid
                if let userId = user?.uid {
                    // Create a Task to handle the async call
                    Task {
                        let username = await self?.firebaseManager.fetchUsername(userId: userId)
                        // Update UI on main thread
                        await MainActor.run {
                            self?.username = username
                            self?.needsUsername = username == nil
                        }
                    }
                }
            }
        }
    }
    
    func setUsername(_ username: String, completion: @escaping (Bool, String?) -> Void) {
            guard let userId = userId,
                let email = Auth.auth().currentUser?.email else { return }
            
            // Check if username is already taken
            let db = Firestore.firestore()
            db.collection("usernames").document(username).getDocument { [weak self] document, error in
                if let document = document, document.exists {
                    completion(false, "Username already taken")
                    return
                }
                
                // If username is available, save it
                db.collection("users").document(userId).setData(
                    [
                    "distance_used" : 0,
                    "email" : email,
                    "friends" : [],
                    "pending_friends" : [],
                    "inventory" : [],
                    "profilePictureURL" : "",
                    "total_distance" : 0,
                    "username": username,
                    ],
                    merge: true) { error in
                    if let error = error {
                        completion(false, error.localizedDescription)
                        return
                    }
                    
                    // Create username reference
                    db.collection("usernames").document(username).setData([
                        "userid": userId
                    ]) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                completion(false, error.localizedDescription)
                            } else {
                                self?.username = username
                                self?.needsUsername = false
                                completion(true, nil)
                            }
                        }
                    }
                }
            }
        }
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var email: String
    @Binding var password: String

    var body: some View {
        VStack(spacing: 20) {
            Text("Cartrekk")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)

            TextField("Email", text: $email)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            SecureField("Password", text: $password)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.horizontal)

            Button(action: {
                loginWithEmail()
            }) {
                Text("Login")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            Button(action: {
                signInWithGoogle()
            }) {
                HStack {
                    Image(systemName: "g.circle.fill")
                    Text("Sign in with Google")
                }
                .font(.title2)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }

    func loginWithEmail() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Login error: \(error.localizedDescription)")
            }
        }
    }
    
    func signInWithGoogle() {
        guard let presentingViewController = (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController) else {
            print("Error: No root view controller found.")
            return
        }

        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { signInResult, error in
            if let error = error {
                print("Google Sign-In error: \(error.localizedDescription)")
                return
            }

            guard let user = signInResult?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Error: Missing ID Token.")
                return
            }

            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
                                                       accessToken: user.accessToken.tokenString)

            Auth.auth().signIn(with: credential) { result, error in
                if let error = error {
                    print("Firebase authentication error: \(error.localizedDescription)")
                }
            }
        }
    }
}

struct UsernameSetupView: View {
    var onComplete: () -> Void = {}
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var username: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Create Username")
                .font(.largeTitle)
                .bold()
            
            TextField("Username", text: $username)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            Button(action: {
                createUsername()
            }) {
                Text("Set Username")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(isLoading || username.isEmpty)
            .padding(.horizontal)
        }
        .padding()
    }
    
    private func createUsername() {
       isLoading = true
       authManager.setUsername(username) { success, error in
           isLoading = false
           if let error = error {
               errorMessage = error
           } else if success {
               // Call onComplete when username is successfully set
               onComplete()
           }
       }
   }
}

// MARK: - Main App View
struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ExploreView()
                .tabItem {
                    Image(systemName: "globe")
                    Text("Explore")
                }
                .tag(0)

                
            MapView()
                .tabItem {
                    Image(systemName: "map")
                    Text("Map")
                }
                .tag(1)
                
            ProfileView()
                .tabItem {
                    Image(systemName: "person.circle")
                    Text("Profile")
                }
                .tag(2)
        }
        .accentColor(.blue)
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .preferredColorScheme(.dark)
    }
}


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
    
    
    
    var body: some View {
        NavigationView {
            VStack {
                // Header with profile image and friends button
                HStack {
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
                        .foregroundColor(.white)
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
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    } else if let profileImageURL = viewModel.profilePictureURL, !profileImageURL.isEmpty,
                              let url = URL(string: profileImageURL),
                              let imageData = try? Data(contentsOf: url),
                              let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
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
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.blue)
                                .clipShape(Circle())
                        }
                    }
                    .frame(width: 100, height: 100)
                    
                    if isUploadingImage {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                    .foregroundColor(.white)
                    .padding(.top, 10)

                VStack(spacing: 15) {
                    Text("Total Miles: \(String(format: "%.2f", garageManager.totalMiles)) mi")
                        .font(.headline)

                    Text("Usable Points: \(String(format: "%.2f", garageManager.usableMiles))")
                        .font(.headline)
                        .foregroundColor(garageManager.usableMiles >= 100 ? .green : .red)
                    
                    NavigationLink(destination: PastRoutesView()) {
                        ProfileButton(title: "Past Routes", icon: "map")
                    }
                    
                    ProfileButton(title: "Settings", icon: "gearshape")
                    
                    ProfileButton(title: "Support", icon: "questionmark.circle")
                    
                    Button (action:{
                        tutorialManager.triggerTutorial()
                    }) {
                        ProfileButton(title: "Tutorial", icon: "questionmark.circle")
                    }
                    
                    Button(action: logout) {
                        ProfileButton(title: "Log Out", icon: "arrow.backward", color: .red)
                    }
                    
                }
                .padding(.top, 30)
                
                Spacer()
            }
            .sheet(isPresented: $showFriendsSheet) {
               FriendsView()
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
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
        }
        .onAppear {
            if let userId = authManager.userId {
                Task {
                    await viewModel.loadRoutes(userId: userId)
                    garageManager.fetchTotalMiles(userId: userId)
                    await viewModel.loadUserProfile(userId: userId)
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
}

// MARK: - Profile Button Component
struct ProfileButton: View {
    var title: String
    var icon: String
    var color: Color = .blue
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
                .imageScale(.large)
            
            Text(title)
                .font(.title3)
                .bold()
                .foregroundColor(.white)
            
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

// MARK: - Past Routes View
struct PastRoutesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var garageManager = GarageManager.shared
    @StateObject private var viewModel = ProfileViewModel()
    
    var totalDistanceTraveled: Double {
        viewModel.routes.reduce(0) { $0 + $1.distance }
    }

    var body: some View {
        VStack {
            Text("Past Routes")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .padding(.top, 20)
            
            if viewModel.routes.isEmpty {
                Text("No past routes available.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(viewModel.routes, id: \.docID) { route in
                   RouteRow(route: route, onDelete: {
                       // Remove the route locally from viewModel.routes
                       if let index = viewModel.routes.firstIndex(where: { $0.docID == route.docID }) {
                           viewModel.routes.remove(at: index)
                       }
                   })
               }
               .background(Color.black)
            }
            
            Spacer()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .padding()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink(destination: GarageView()) {
                    Text("Garage")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
        }
        .onAppear {
            if let userId = authManager.userId {
                Task {
                    await viewModel.loadRoutes(userId: userId)
                    // Use this when tables per user are added
                    garageManager.fetchTotalMiles(userId: userId)
//                    garageManager.fetchTotalMiles(userId: "userid_1")
                }
            }
        }
    }
}

// MARK: - Route Row
struct RouteRow: View {
    let route: FirestoreManager.fb_Route
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isCurrentlyPublic: Bool
    // Add a callback for deletion
    var onDelete: () -> Void
    
    init(route: FirestoreManager.fb_Route, onDelete: @escaping () -> Void) {
        self.route = route
        self.onDelete = onDelete
        _isCurrentlyPublic = State(initialValue: route.isPublic)
    }
    
    @State private var showDeleteConfirmation = false
    @State private var showPostConfirmation = false
    @State private var isLiked = false
    @State private var showCommentsSheet = false
    @State private var routeComments: [Comment] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Separate HStack for the header with delete button
            HStack {
                VStack(alignment: .leading) {
                    Text(formatDate(route.createdAt))
                        .font(.headline)
                }
                
                Spacer()
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .confirmationDialog(
                    "Delete Route",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        Task {
                            if await viewModel.deleteRoute(routeId: route.docID) {
                                // Call the onDelete callback to notify parent view
                                onDelete()
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            
            // Route title if available
            let routeName = route.name
            if !routeName.isEmpty {
                Text(routeName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top, 4)
            }
            
            // Rest of the route information
            HStack {
                Text(String(format: "%.2f m", route.distance))
                Spacer()
                Text(formatDuration(route.duration))
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            TabView {
                // Map view with the route
                let polyline = Polyline(encodedPolyline: route.polyline)
                
                if let locations = polyline.locations, !locations.isEmpty {
                    Map {
                        Marker("Start",
                               coordinate: locations.first!.coordinate)
                        .tint(.green)
                        
                        Marker("End",
                               coordinate: locations.last!.coordinate)
                        .tint(.red)
                        
                        MapPolyline(coordinates: locations.map { $0.coordinate })
                            .stroke(
                                Color.blue.opacity(0.8),
                                style: StrokeStyle(
                                    lineWidth: 4,
                                    lineCap: .butt,
                                    lineJoin: .round,
                                    miterLimit: 10
                                )
                            )
                    }
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .disabled(true)
                    .allowsHitTesting(false)
                }

                if let routeImages = route.routeImages, !routeImages.isEmpty {
                    ForEach(routeImages, id: \.self) { photoUrl in
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image.resizable()
                                .scaledToFit()
                                .frame(height: 250)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 250)

            
            HStack(spacing: 20) {
                // Likes display
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.red)
                    Text("\(route.likes)")
                        .foregroundColor(.gray)
                }
                
                // Comments display with button to view
                Button(action: {
                    Task {
                        routeComments = await viewModel.loadCommentsForRoute(routeId: route.docID)
                        showCommentsSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "message")
                        Text("Comments")
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                // Public/Private toggle
                Button(action: {
                    print("Button tapped") // Debug print
                    showPostConfirmation = true
                }) {
                    HStack {
                        Image(systemName: isCurrentlyPublic ? "globe" : "globe.slash")
                        Text(isCurrentlyPublic ? "Public" : "Private")
                    }
                    .foregroundColor(isCurrentlyPublic ? .blue : .gray)
                }
                .buttonStyle(.borderless)
                .confirmationDialog(
                    isCurrentlyPublic ? "Make Private" : "Make Public",
                    isPresented: $showPostConfirmation
                ) {
                    Button(isCurrentlyPublic ? "Make Private" : "Make Public") {
                        // Toggle the UI state immediately
                        isCurrentlyPublic.toggle()
                        
                        // Update Firestore in background
                        Task {
                            await viewModel.togglePublicStatus(routeId: route.docID)
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        print("Cancel tapped") // Debug print
                    }
                }
            }
            
            .padding(.vertical, 8)
            
            // Route description if available
            let description = route.description
            if !description.isEmpty {
                Text(description)
                    .font(.body)
                    .padding(.vertical, 4)
            }
        }
        
        .sheet(isPresented: $showCommentsSheet) {
            NavigationView {
                List {
                    if !routeComments.isEmpty {
                        ForEach(routeComments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.username)
                                    .fontWeight(.bold)
                                Text(comment.text)
                                Text(comment.timestamp, style: .relative)
                                    .foregroundColor(.gray)
                            }
                            .font(.caption)
                        }
                    } else {
                        Text("No comments yet")
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
                .navigationTitle("Comments")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            showCommentsSheet = false
                        }
                    }
                }
            }
        }
    }
    
    // Keep your existing helper functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Profile View Model
class ProfileViewModel: ObservableObject {
    @Published var routes: [FirestoreManager.fb_Route] = []
    @Published var profilePictureURL: String?
    private let db = FirestoreManager()
    
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
}

class TutorialManager: ObservableObject {
    @Published var showTutorial: Bool = false
    
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
            print("Error loading user profile: \(error)")
        }
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


#Preview {
    ContentView()
}
