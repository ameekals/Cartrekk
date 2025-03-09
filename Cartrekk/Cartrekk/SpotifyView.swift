//
//  SpotifyView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 3/5/25.
//

import SwiftUI
import SafariServices
import FirebaseCore

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
            URLQueryItem(name: "scope", value: "user-read-recently-played user-read-email user-read-private"),
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

// Simple model for Spotify track data
struct SpotifyTrack {
    let id: String
    let name: String
    let artists: String
    let albumName: String
    let albumImageUrl: String?
    let playedAt: String
}


class SpotifyFuncManager: ObservableObject {
    
    func refreshSpotifyToken(userId: String, refreshToken: String) async -> String? {
        // Set up the token refresh request
        let tokenURL = "https://accounts.spotify.com/api/token"
        var tokenRequest = URLRequest(url: URL(string: tokenURL)!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let clientId = "fa7a4a634c29432cb81412d1157e6d19"
        let clientSecret = "427745ea445b48a8b9588b92c7a18900" // Replace with actual secret
        
        // Basic auth header with client ID and secret
        let authString = "\(clientId):\(clientSecret)"
        if let authData = authString.data(using: .utf8) {
            let base64Auth = authData.base64EncodedString()
            tokenRequest.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
        
        // Request parameters
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        tokenRequest.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: tokenRequest)
            
            if let tokenResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let newAccessToken = tokenResponse["access_token"] as? String,
               let expiresIn = tokenResponse["expires_in"] as? Int {
                
                // Calculate new expiration date
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                
                // Update token in Firestore
                try await FirestoreManager.shared.db.collection("users").document(userId).updateData([
                    "spotifyAccessToken": newAccessToken,
                    "spotifyTokenExpiration": expirationDate
                ])
                
                print("Successfully refreshed Spotify access token")
                return newAccessToken
            }
        } catch {
            print("Error refreshing Spotify token: \(error)")
        }
        
        return nil
    }
    
    func fetchSpotifyData(userId: String, after: Int64? = nil) async -> [SpotifyTrack]? {
        
        do {
            // Get user's Spotify tokens
            let document = try await FirestoreManager.shared.db.collection("users").document(userId).getDocument()
            guard let data = document.data(),
                  let accessToken = data["spotifyAccessToken"] as? String,
                  let tokenExpiration = data["spotifyTokenExpiration"] as? Timestamp,
                  let refreshToken = data["spotifyRefreshToken"] as? String else {
                print("Spotify tokens not found")
                return nil
            }
            
            // Check if token is expired
            var currentToken = accessToken
            if tokenExpiration.dateValue() <= Date() {
                print("Token expired, refreshing...")
                if let newToken = await refreshSpotifyToken(userId: userId, refreshToken: refreshToken) {
                    currentToken = newToken
                } else {
                    print("Failed to refresh token")
                    return nil
                }
            }
            
            // Build the URL with query parameters
            var urlComponents = URLComponents(string: "https://api.spotify.com/v1/me/player/recently-played")!
            var queryItems = [URLQueryItem(name: "limit", value: "50")] // Max tracks to return
            
            if let after = after {
                queryItems.append(URLQueryItem(name: "after", value: String(after)))
            }
            
            urlComponents.queryItems = queryItems
            
            // Now make your API request with the valid token
            var request = URLRequest(url: urlComponents.url!)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            
            let (responseData, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("API Response Code: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        print("Error response: \(errorJson)")
                    }
                }
            }
            
            
            
            // Parse the response
            if let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any],
               let items = json["items"] as? [[String: Any]] {
                
                // Process tracks from the response
                var tracks: [SpotifyTrack] = []
                
                for item in items {
                    if let track = item["track"] as? [String: Any],
                       let id = track["id"] as? String,
                       let name = track["name"] as? String,
                       let album = track["album"] as? [String: Any],
                       let albumName = album["name"] as? String,
                       let artists = track["artists"] as? [[String: Any]],
                       let playedAt = item["played_at"] as? String {
                        
                        // Extract artist names
                        let artistNames = artists.compactMap { $0["name"] as? String }
                        
                        // Extract album art if available
                        var albumImageUrl: String? = nil
                        if let images = album["images"] as? [[String: Any]], let firstImage = images.first {
                            albumImageUrl = firstImage["url"] as? String
                        }
                        
                        // Create a track object
                        let spotifyTrack = SpotifyTrack(
                            id: id,
                            name: name,
                            artists: artistNames.joined(separator: ", "),
                            albumName: albumName,
                            albumImageUrl: albumImageUrl,
                            playedAt: playedAt
                        )
                        
                        print(spotifyTrack.name)
                        
                        tracks.append(spotifyTrack)
                    }
                }
                
                print("Fetched \(tracks.count) recently played tracks")
                return tracks
            }
            
            return nil
        } catch {
            print("Error fetching Spotify data: \(error)")
            return nil
        }
    }
    
    func fetchSongsFromSpotify(userId: String, afterTimestamp: Int64) async -> [SpotifyTrack] {
        // First check if the user has Spotify connected
        do {
            let document = try await FirestoreManager.shared.db.collection("users").document(userId).getDocument()
            if let data = document.data(),
               let isConnected = data["spotifyConnected"] as? Bool,
               isConnected {
                if let tracks = await self.fetchSpotifyData(userId: userId, after: afterTimestamp) {
                    return tracks
                }
            }
            return [] // Return empty array if not connected or no tracks
        } catch {
            print("Error fetching Spotify connection status: \(error)")
            return [] // Return empty array on error
        }
    }
}


struct SpotifyTrackRow: View {
    let track: SpotifyTrack
    
    var body: some View {
        HStack(spacing: 12) {
            // Album artwork
            if let albumImageUrl = track.albumImageUrl, let url = URL(string: albumImageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 50, height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else {
                // Fallback image if no album art is available
                Image(systemName: "music.note")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .padding(10)
                    .background(Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Track information
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack {
                    Text(track.artists)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Format and display played time
                    if let playedDate = formatPlayedAt(track.playedAt) {
                        Text(playedDate, style: .time)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Helper function to parse Spotify's ISO 8601 date format
    private func formatPlayedAt(_ dateString: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString)
    }
}

// Create a view that displays all Spotify tracks for a route
struct SpotifyTracksView: View {
    let tracks: [SpotifyTrack]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(.green)
                
                Text("Songs Played During Trip")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(tracks.count)")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding(.bottom, 4)
            
            Divider()
                .background(Color.gray.opacity(0.3))
            
            ForEach(tracks, id: \.id) { track in
                SpotifyTrackRow(track: track)
                
                if track.id != tracks.last?.id {
                    Divider()
                        .background(Color.gray.opacity(0.2))
                }
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground).opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

