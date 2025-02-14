//
//  ContentView.swift
//  Cartrekk
//
//  Created by Ameek Singh on 1/18/25.
//

import SwiftUI
import MapKit
import CoreLocation
import FirebaseAuth
import Firebase
import FirebaseFirestore
import GoogleSignIn
import UIKit


struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        if isLoggedIn {
            
            MainAppView()
        } else {
            LoginView(isLoggedIn: $isLoggedIn, email: $email, password: $password)
        }
    }
}

// MARK: - Login View
struct LoginView: View {
    @Binding var isLoggedIn: Bool
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
            } else {
                isLoggedIn = true
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
                } else {
                    isLoggedIn = true
                }
            }
        }
    }
}

// MARK: - Main App View
struct MainAppView: View {
    
    var body: some View {
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
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Map View with Timer
struct MapView: View {

    @StateObject private var locationService = LocationTrackingService()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: Route?
            // Timer States
    @State private var isTracking = false
    @State private var startTime: Date? = nil
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var timer: Timer? = nil
    
    
    
    @State private var showCamera = false
    @State private var capturedImage: UIImage?

    var body: some View {
        VStack {
            
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                if !locationService.locations.isEmpty {
                    MapPolyline(coordinates: locationService.locations.map { $0.coordinate })
                        .stroke(.blue, lineWidth: 3)
                }
            }
            
            
            VStack {
                Text(formatTimeInterval(elapsedTime)) // Timer
                    .font(.title2)
                    .bold()
                
//                    Text(String(format: "%.2f km", locationService.totalDistance / 1000)) // Distance in km
//                        .font(.headline)
                Text(String(format: "%.2f mi", locationService.totalDistance * 0.00062137)) // Distance in miles
                    .font(.headline)
            }
            .padding()
            HStack{
                Spacer()
                Spacer(minLength: 80)
                
                Button(action: {
                    if locationService.isTracking {
                        locationService.stopTracking()
                        route = locationService.saveRoute()
                        stopTracking()
                    } else {
                        locationService.startTracking()
                        startTracking()
                    }
                }) {
                    Text(locationService.isTracking ? "Stop Tracking" : "Start Tracking")
                        .padding()
                        .background(locationService.isTracking ? Color.red : Color.green)
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
            
        
        .sheet(isPresented: $showCamera, onDismiss: {
            if let capturedImage = capturedImage {
                Task {
                    do {
                        let imageURL = try await uploadImageToS3(image: capturedImage, imageName: "capturedImage.jpg", bucketName: "cartrekk-images")
                        print("Image uploaded to S3: \(imageURL)")
                    } catch {
                        print("Upload failed: \(error.localizedDescription)")
                    }
                }
            }
        }) {
            CameraView(image: $capturedImage)
        }

        
        .onAppear {
            CLLocationManager().requestWhenInUseAuthorization()
        }
    }

    // MARK: - Timer and Tracking Logic
    private func startTracking() {
        isTracking = true
        locationService.startTracking()
        startTime = Date()
        elapsedTime = 0.0

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopTracking() {
        isTracking = false
        locationService.stopTracking()
        timer?.invalidate()
        timer = nil
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}




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






#Preview {
    MapView()
}
