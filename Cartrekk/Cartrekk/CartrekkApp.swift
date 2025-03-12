//
//  CartrekkApp.swift
//  Cartrekk
//
//  Created by Ameek Singh on 1/18/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn
import AWSClientRuntime
import AWSS3
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    
    var db: Firestore!
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    
    // Add this method to handle URL callbacks
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        print("AppDelegate received URL: \(url.absoluteString)")
        
        // Check if it's a Spotify callback
        if url.absoluteString.starts(with: "cartrekk://spotify-callback") {
            handleSpotifyCallback(url: url)
            return true
        }
        
        // Let Google Sign-In handle its URLs
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    private func handleSpotifyCallback(url: URL) {
        print("Handling Spotify callback URL: \(url.absoluteString)")
        
        // Extract the authorization code
        let spotifyAuth = SpotifyAuthManager()
        if let code = spotifyAuth.extractCodeFromURL(url) {
            print("Successfully extracted Spotify auth code: \(code)")
            
            // Exchange code for token
            Task {
                // This is a simplified version - in a real app, you'd want to store these tokens securely
                let clientId = "fa7a4a634c29432cb81412d1157e6d19"
                let clientSecret = "427745ea445b48a8b9588b92c7a18900" // Replace with your actual client secret
                let redirectUri = "cartrekk://spotify-callback"
                
                // Exchange code for token
                let tokenURL = "https://accounts.spotify.com/api/token"
                
                var tokenRequest = URLRequest(url: URL(string: tokenURL)!)
                tokenRequest.httpMethod = "POST"
                tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                
                let parameters = [
                    "grant_type": "authorization_code",
                    "code": code,
                    "redirect_uri": redirectUri,
                    "client_id": clientId,
                    "client_secret": clientSecret
                ]
                
                let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                tokenRequest.httpBody = bodyString.data(using: .utf8)
                
                do {
                    let (data, _) = try await URLSession.shared.data(for: tokenRequest)
                    
                    if let tokenResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let accessToken = tokenResponse["access_token"] as? String,
                       let refreshToken = tokenResponse["refresh_token"] as? String,
                       let expiresIn = tokenResponse["expires_in"] as? Int {
                        
                        // Store tokens securely - in this example we'll store in Firestore
                        // but consider using Keychain in a production app
                        let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                        
                        // Now fetch user profile
                        var profileRequest = URLRequest(url: URL(string: "https://api.spotify.com/v1/me")!)
                        profileRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                        
                        let (profileData, _) = try await URLSession.shared.data(for: profileRequest)
                        
                        if let profileInfo = try? JSONSerialization.jsonObject(with: profileData) as? [String: Any],
                           let displayName = profileInfo["display_name"] as? String {
                            
                            // Get profile image if available
                            var profileImageURL: String? = nil
                            if let images = profileInfo["images"] as? [[String: Any]],
                               let firstImage = images.first,
                               let imageUrl = firstImage["url"] as? String {
                                profileImageURL = imageUrl
                            }
                            print("\ndisplay name: " + displayName)
                            print("\naccess token" + accessToken)
                            print("\nrefresh token" + refreshToken)
                            
                            // Update user's Spotify connection status in Firestore
                            if let userId = Auth.auth().currentUser?.uid {
                                var userData: [String: Any] = [
                                    "spotifyConnected": true,
                                    "spotifyUsername": displayName,
                                    "spotifyAccessToken": accessToken,
                                    "spotifyRefreshToken": refreshToken,
                                    "spotifyTokenExpiration": expirationDate
                                ]
                                
                                if let imageURL = profileImageURL {
                                    userData["spotifyProfileImageURL"] = imageURL
                                }
                                
                                FirestoreManager.shared.db.collection("users").document(userId).updateData(userData) { error in
                                    if let error = error {
                                        print("Error updating Spotify user info: \(error)")
                                    } else {
                                        print("Successfully stored Spotify user info and tokens")

                                        // Notify the UI to update
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("SpotifyConnectionChanged"),
                                            object: nil,
                                            userInfo: ["connected": true]
                                        )
                                    }
                                }
                            } else {
                                print("User not logged in")
                            }
                        }
                    }
                } catch {
                    print("Error exchanging code for token: \(error)")
                }
            }
        } else {
            print("Failed to extract code from URL: \(url)")
        }
    }
}

@main
struct CartrekkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    print("Received URL in onOpenURL: \(url.absoluteString)")
                    
                    // Handle Spotify callback
                    if url.absoluteString.starts(with: "cartrekk://spotify-callback") {
                        // Forward to AppDelegate
                        _ = appDelegate.application(UIApplication.shared, open: url, options: [:])
                    } else {
                        // Handle Google Sign-In
                        GIDSignIn.sharedInstance.handle(url)
                    }
                }
        }
    }
}
