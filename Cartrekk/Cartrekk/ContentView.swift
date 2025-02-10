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

//            Button(action: {
//                signInWithGoogle()
//            }) {
//                HStack {
//                    Image(systemName: "g.circle.fill")
//                    Text("Sign in with Google")
//                }
//                .font(.title2)
//                .padding()
//                .frame(maxWidth: .infinity)
//                .background(Color.red)
//                .foregroundColor(.white)
//                .cornerRadius(10)
//            }
//            .padding(.horizontal)
        }
        .padding()
    }

    // Email/Password Authentication
    func loginWithEmail() {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Login error: \(error.localizedDescription)")
            } else {
                isLoggedIn = true
            }
        }
    }

    // Google Sign-In
//    func signInWithGoogle() {
//        guard let clientID = FirebaseApp.app()?.options.clientID else { return }
//
//        let config = GIDConfiguration(clientID: clientID)
//        guard let rootViewController = UIApplication.shared.windows.first?.rootViewController else { return }
//
//        GIDSignIn.sharedInstance.signIn(with: config, presenting: rootViewController) { user, error in
//            if let error = error {
//                print("Google Sign-In error: \(error.localizedDescription)")
//                return
//            }
//
//            guard let authentication = user?.authentication,
//                  let idToken = authentication.idToken else { return }
//
//            let credential = GoogleAuthProvider.credential(withIDToken: idToken,
//                                                           accessToken: authentication.accessToken)
//
//            Auth.auth().signIn(with: credential) { result, error in
//                if let error = error {
//                    print("Firebase authentication error: \(error.localizedDescription)")
//                } else {
//                    isLoggedIn = true
//                }
//            }
//        }
//    }
}

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

struct MapView: View {

    @StateObject private var locationService = LocationTrackingService()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var route: Route?
    
    var body: some View {
            VStack {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    
                    // Draw the route if we have locations
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
                .padding()
            }
            .onAppear {
                CLLocationManager().requestWhenInUseAuthorization()
            }
        }
}

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

    // MARK: - Helper Method
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
