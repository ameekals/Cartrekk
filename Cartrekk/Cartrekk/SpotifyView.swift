//
//  SpotifyView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 3/5/25.
//

import SwiftUI
import SafariServices

// Create a simple SpotifyAuth model
class SpotifyAuthManager: ObservableObject {
    // Replace with your actual client ID
    private let clientId = "fa7a4a634c29432cb81412d1157e6d19" // Your client ID from screenshot
    private let redirectUri = "cartrekk://spotify-callback" // As configured in your Info.plist
    
    func getSpotifyAuthURL() -> URL? {
        // Construct the authorization URL
        var components = URLComponents(string: "https://accounts.spotify.com/authorize")!
        
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectUri),
            URLQueryItem(name: "scope", value: "user-read-private user-read-email"),
            URLQueryItem(name: "show_dialog", value: "true")
        ]
        
        print("Auth URL: \(components.url?.absoluteString ?? "nil")")
        return components.url
    }
    
    func extractCodeFromURL(_ url: URL) -> String? {
        print("Extracting code from: \(url.absoluteString)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            print("Could not create URLComponents")
            return nil
        }
        
        guard let queryItems = components.queryItems else {
            print("No query items found")
            return nil
        }
        
        for item in queryItems {
            print("Query item: \(item.name) = \(item.value ?? "nil")")
        }
        
        return queryItems.first(where: { $0.name == "code" })?.value
    }
}

// Create a simple Safari web view for authentication
struct SpotifyLoginView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var spotifyAuth = SpotifyAuthManager()
    
    // To handle automatic dismissal after successful connection
    @State private var connectionObserver: NSObjectProtocol? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "music.note")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.green)
                    .padding(.top, 40)
                
                Text("Connect to Spotify")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Link your Spotify account to share music from your rides")
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    if let url = spotifyAuth.getSpotifyAuthURL() {
                        UIApplication.shared.open(url, options: [:]) { success in
                            print("Opened Spotify auth URL: \(success)")
                            
                            // If failed to open URL, show an alert
                            if !success {
                                // In a real app, you would show an alert here
                                print("Failed to open Spotify auth URL")
                            }
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "link")
                        Text("Connect with Spotify")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(width: 250)
                    .background(Color.green)
                    .cornerRadius(10)
                }
                .padding(.top, 20)
                
                Spacer()
            }
            .navigationTitle("Spotify Connection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("Cancel")
                    }
                }
            }
            .onAppear {
                // Set up notification observer for successful Spotify connection
                connectionObserver = NotificationCenter.default.addObserver(
                    forName: NSNotification.Name("SpotifyConnectionChanged"),
                    object: nil,
                    queue: .main
                ) { notification in
                    if let connected = notification.userInfo?["connected"] as? Bool, connected {
                        // Connection successful, dismiss this view
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onDisappear {
                // Remove observer when view disappears
                if let observer = connectionObserver {
                    NotificationCenter.default.removeObserver(observer)
                }
            }
        }
    }
}

// Safari view controller wrapper
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        return SFSafariViewController(url: url)
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
