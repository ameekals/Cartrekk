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
    
    var body: some View {
        NavigationView {
            VStack {
                // Profile Image
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.gray)
                    .padding(.top, 40)
                
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
            .frame(maxWidth: .infinity)
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationBarHidden(true)
        }
        .onAppear {
            if let userId = authManager.userId {
                Task {
                    await viewModel.loadRoutes(userId: userId)
                    garageManager.fetchTotalMiles(userId: userId)
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
            
            // Rest of the route information
            HStack {
                Text(String(format: "%.2f m", route.distance))
                Spacer()
                Text(formatDuration(route.duration))
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
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
                .frame(height: 200)
                .cornerRadius(10)
            }
            HStack(spacing: 20) {
                // Likes display
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.red)
                    Text("\(route.likes)")
                        .foregroundColor(.gray)
                }
                
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
}

class TutorialManager: ObservableObject {
    @Published var showTutorial: Bool = false
    
    func triggerTutorial() {
        showTutorial = true
    }
}

struct TutorialView: View {
    var onComplete: () -> Void
    @State private var currentPage = 0
    
    // Tutorial content - customize as needed
    let tutorialPages = [
        TutorialPage(
            title: "Welcome to CarTrekk",
            description: "Track your drives and share your adventures with friends.",
            imageName: "car.fill"
        ),
        TutorialPage(
            title: "Record Your Journeys",
            description: "Tap the car button to start recording a new route. The button turns red while recording.",
            imageName: "record.circle"
        ),
        TutorialPage(
            title: "Capture Moments",
            description: "Take photos during your journey to remember special moments and places.",
            imageName: "camera.circle.fill"
        ),
        TutorialPage(
            title: "Share Routes with Friends",
            description: "Publish your routes with friends to share your adventures",
            imageName: "map.fill"
        ),
        TutorialPage(
            title: "Open Lootboxes and Earn Rewards",
            description: "Use the miles you've driven to open lootboxes and earn rewards!",
            imageName: "gift.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // App logo or icon
                Image(systemName: "car.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.bottom, 40)
                
                // Current tutorial page content
                VStack(spacing: 20) {
                    Image(systemName: tutorialPages[currentPage].imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundColor(.white)
                        .padding()
                    
                    Text(tutorialPages[currentPage].title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(tutorialPages[currentPage].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<tutorialPages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 20)
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            Text("Previous")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            if currentPage < tutorialPages.count - 1 {
                                currentPage += 1
                            } else {
                                onComplete()
                            }
                        }
                    }) {
                        Text(currentPage < tutorialPages.count - 1 ? "Next" : "Get Started")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

// Simple data structure for tutorial pages
struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
}

#Preview {
    ContentView()
}
