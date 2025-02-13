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
                
                NavigationLink(destination: TimerView()) {
                    Text("Start")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
                NavigationLink(destination: MapView()) {
                    Text("MAP")
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

// MARK: - Map View
struct MapView: View {
    
    @StateObject private var locationService = LocationTrackingService()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: Route?
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    
    
    var body: some View {
        NavigationView {
            ZStack {
                VStack {
                    Spacer()
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        if !locationService.locations.isEmpty {
                            MapPolyline(coordinates: locationService.locations.map { $0.coordinate })
                                .stroke(.blue, lineWidth: 3)
                        }
                    }
                    
                    Button(action: {
                        if locationService.isTracking {
                            locationService.stopTracking()
                            route = locationService.saveRoute()
                        } else {
                            locationService.startTracking()
                        }
                    }) {
                        Text(locationService.isTracking ? "Stop Tracking" : "Start Tracking")
                            .padding()
                            .background(locationService.isTracking ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
                HStack {
                    Button(action: {
                        if locationService.isTracking {
                            locationService.stopTracking()
                            route = locationService.saveRoute()
                        } else {
                            locationService.startTracking()
                        }
                    }) {
                        Text(locationService.isTracking ? "Stop Tracking" : "Start Tracking")
                            .padding()
                            .background(locationService.isTracking ? Color.red : Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Text(String(format: "%.2f km", locationService.totalDistance / 1000))
                        .font(.headline)
                        .padding()
            }
            
            
            .toolbar {
                
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
                    
                
            }
            
            .sheet(isPresented: $showCamera) {
                CameraView(image: $capturedImage)
            }
            .onAppear {
                CLLocationManager().requestAlwaysAuthorization()
            }
        }
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





// MARK: - Timer View
struct TimerView: View {
    @State private var isRecording = false
    @State private var timer: Timer? = nil
    @State private var startTime: Date? = nil
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var timesTraveled: [String] = []
    @State private var distanceTraveled: Double = 0.0 // Distance traveled variable

    var body: some View {
        VStack(spacing: 20) {
            // Timer Display
            Text(formatTimeInterval(elapsedTime))
                .font(.largeTitle)
                .bold()

            // Start/Stop Button
            Button(action: {
                isRecording ? stopRecording() : startRecording()
            }) {
                Text(isRecording ? "End Recording" : "Start Recording")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            // Stats List
            List {
                Section(header: Text("Stats")) {
                    Text("Distance Traveled: \(distanceTraveled, specifier: "%.2f") mi")
                }
                Section(header: Text("Time Traveled")) {
                    ForEach(timesTraveled, id: \.self) { time in
                        Text("Time: \(time)")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .padding()
        .navigationBarTitle("Timer", displayMode: .inline)
    }

    // MARK: - Timer Logic
    private func startRecording() {
        isRecording = true
        startTime = Date()
        elapsedTime = 0.0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        if let startTime = startTime {
            elapsedTime = Date().timeIntervalSince(startTime)
            timesTraveled.append(formatTimeInterval(elapsedTime))
        }
        elapsedTime = 0.0
        startTime = nil
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    MapView()
}
