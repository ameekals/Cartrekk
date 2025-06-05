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
import SafariServices


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
                        GarageManager.shared.fetchTotalMiles(userId: userId)
                    }
                }
            }
        }
    }
    
    func setUsername(_ username: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = userId,
            let email = Auth.auth().currentUser?.email else {
            completion(false, "User not authenticated")
            return
        }
        
        Task {
            var s3UserID: String = ""
            
            // Generate Cognito Identity when creating the username
            do {
                s3UserID = try await AWSService.shared.generateNewCognitoIdentity()
                print("Successfully generated Cognito ID: \(s3UserID)")
            } catch {
                print("Failed to generate Cognito ID: \(error)")
                DispatchQueue.main.async {
                    completion(false, "Failed to generate user credentials")
                }
                return
            }
            
            // Check if username is already taken
            let db = Firestore.firestore()
            db.collection("usernames").document(username).getDocument { [weak self] document, error in
                if let document = document, document.exists {
                    completion(false, "Username already taken")
                    return
                }
                
                // If username is available, save it along with the Cognito ID
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
                    "equiped_car" : "",
                    "cognitoIdentityId": s3UserID  // Add the Cognito ID here
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
}

// MARK: - Login View

struct LoginView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var email: String
    @Binding var password: String

    var body: some View {
        VStack(spacing: 20) {
            
            Image("car_shrek_icon") 
                .resizable()
                .scaledToFit()
                .padding(.bottom, 10)
            
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
    @StateObject private var trackingManager = TrackingStateManager.shared
    @State private var selectedTab = 1
    
    var body: some View {
        ZStack {
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
            // Hide tab bar when tracking is active
            .toolbar(trackingManager.isTracking ? .hidden : .visible, for: .tabBar)
            
            // Full screen tracking overlay when tracking
            if trackingManager.isTracking && selectedTab == 1 {
                TrackingOverlayView()
                    .ignoresSafeArea(.all)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: trackingManager.isTracking)
            }
        }
    }
}


#Preview {
    ContentView()
}
