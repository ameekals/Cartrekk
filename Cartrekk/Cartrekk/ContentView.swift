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
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        if authManager.isLoggedIn {
            MainAppView()
                .environmentObject(authManager) // Inject auth manager to access user ID
        } else {
            LoginView(email: $email, password: $password)
                .environmentObject(authManager)
        
        }
    }
}

// MARK: - Auth Manager

class AuthenticationManager: ObservableObject {
    @Published var isLoggedIn: Bool = false
    @Published var userId: String? = nil
    
    init() {
        // Set up authentication state listener
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.isLoggedIn = user != nil
                self?.userId = user?.uid
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
                // AuthenticationManager will automatically update state
            }
        }
    }
}

// MARK: - Main App View
struct MainAppView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Text("Welcome! Your user ID is: \(authManager.userId ?? "Not found")")
        
        
        NavigationView {
            VStack(spacing: 20) {
                Text("Cartrekk")
                    .font(.largeTitle)
                    .bold()
                
                NavigationLink(destination: MapView()) {
                    Text("START")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                NavigationLink(destination: ProfileView()) {
                    Text("User Profile")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                NavigationLink(destination: ExploreView()) {
                    Text("Explore")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                Button(action: {
                    do {
                        try Auth.auth().signOut()
                        authManager.isLoggedIn = false
                        authManager.userId = nil
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }) {
                    Text("Log Out")
                        .font(.subheadline)  // Changed from .title2 to .subheadline
                        .padding(.vertical, 8)  // Reduced vertical padding
                        .padding(.horizontal, 20)  // Added horizontal padding
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(8)  // Slightly reduced corner radius
                }
                .padding(.top, 20)
               
           }
           .padding()
           .navigationBarHidden(true)
       }
   }
}

class TrackingStateManager: ObservableObject {
    static let shared = TrackingStateManager()
    let locationService = LocationTrackingService.shared
    
    @Published var isTracking = false
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0.0
    private var timer: Timer?
    
    private init() {}
    
    func startTracking() {
        isTracking = true
        locationService.startTracking()
        startTime = Date()
        elapsedTime = 0.0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }
    
    func stopTracking(userId: String) {
        isTracking = false
        timer?.invalidate()
        timer = nil
        locationService.saveRoute(raw_userId: userId, time: elapsedTime)
        elapsedTime = 0.0
    }
}


// MARK: - Map View
// Modified MapView
struct MapView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var locationService = LocationTrackingService.shared
    @StateObject private var trackingManager = TrackingStateManager.shared
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: Route?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        let UUid: String = authManager.userId!
        VStack {
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                if !locationService.locations.isEmpty {
                    MapPolyline(coordinates: locationService.locations.map { $0.coordinate })
                        .stroke(.blue, lineWidth: 3)
                }
            }
            
            VStack {
                Text(formatTimeInterval(trackingManager.elapsedTime))
                    .font(.title2)
                    .bold()
                Text(String(format: "%.2f mi", locationService.totalDistance * 0.00062137))
                    .font(.headline)
            }
            .padding()
            
            HStack {
                Spacer()
                Spacer(minLength: 80)
                
                Button(action: {
                    if trackingManager.isTracking {
                        trackingManager.stopTracking(userId: UUid)
                        locationService.stopTracking()
                        

                    } else {
                        CLLocationManager().requestAlwaysAuthorization()
                        trackingManager.startTracking()
                    }
                }) {
                    Text(trackingManager.isTracking ? "Stop Tracking" : "Start Tracking")
                        .padding()
                        .background(trackingManager.isTracking ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Spacer()
                Button(action: {
                    showCamera = true
                }) {
                    Image(systemName: "camera.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white)
                        .background(Color.blue.opacity(0.9))
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .onAppear {
            CLLocationManager().requestWhenInUseAuthorization()
            CLLocationManager().requestAlwaysAuthorization()
        }
        .sheet(isPresented: $showCamera, onDismiss: handleCameraDismiss){
            CameraView(image: $capturedImage)
        }
    }
    
    private func handleCameraDismiss() {
        if let capturedImage = capturedImage {
            Task {
                do {
                    let imageURL = try await uploadImageToS3(image: capturedImage,
                                                           imageName: "capturedImage.jpg",
                                                           bucketName: "cartrekk-images")
                    print("Image uploaded to S3: \(imageURL)")
                } catch {
                    print("Upload failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}


// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}




// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var viewModel = ProfileViewModel()
    
    var body: some View {
        VStack {
            Text("Profile")
                .font(.largeTitle)
                .bold()
                .padding()
            
            List(viewModel.routes, id: \.docID) { route in
                RouteRow(route: route) {
                    // Handle actual deletion
                    Task {
                        if await viewModel.deleteRoute(routeId: route.docID) {
                            // If deletion was successful, reload the routes
                            if let userId = authManager.userId {
                                await viewModel.loadRoutes(userId: userId)
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            if let userId = authManager.userId {
                Task {
                    await viewModel.loadRoutes(userId: userId)
                }
            }
        }
    }
}


// MARK: - Route Row
struct RouteRow: View {
    let route: FirestoreManager.fb_Route
    @State private var showDeleteConfirmation = false
    var onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Separate HStack for the header with delete button
            HStack {
                VStack(alignment: .leading) {
                    Text(formatDate(route.createdAt))
                        .font(.headline)
                }
                
                Spacer()
            
                // Isolated delete button
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
                        onDelete()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Are you sure you want to delete this route? This action cannot be undone.")
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
        }
        .padding(.vertical, 8)
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
}

#Preview {
    ContentView()
}
