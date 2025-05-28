//
//  SpotifyAPITester.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 3/7/25.
//

import Foundation
import Firebase
import FirebaseFirestore

class SpotifyAPITester {
    
    private let firestoreManager: FirestoreManager
    
    init(firestoreManager: FirestoreManager) {
        self.firestoreManager = firestoreManager
    }
    
    // Main function to test the Spotify API functionality
    func testSpotifyAPI(userId: String) async {
        print("🧪 Starting Spotify API test for user ID: \(userId)")
        
        if let tracks = await fetchSpotifyData(userId: userId, after: Int64(1741420424790.2852)) {
            print("✅ SUCCESS: Retrieved \(tracks.count) tracks")
            
            // Print first 5 tracks for verification
            for (index, track) in tracks.prefix(5).enumerated() {
                print("Track \(index + 1): \(track.name) by \(track.artists)")
                print("   Album: \(track.albumName)")
                print("   Played at: \(track.playedAt)")
                print("   Album art: \(track.albumImageUrl ?? "None")")
                print("   ---")
            }
        } else {
            print("❌ FAILED: Could not retrieve Spotify tracks")
        }
    }
    
    // Existing function from your code, with error printing enhanced
    func fetchSpotifyData(userId: String, after: Int64? = nil) async -> [SpotifyTrack]? {
        print("📡 Fetching Spotify data for user ID: \(userId)")
        
        do {
            // Get user's Spotify tokens
            print("🔑 Retrieving Spotify tokens from Firestore...")
            let document = try await firestoreManager.db.collection("users").document(userId).getDocument()
            guard let data = document.data() else {
                print("❌ Document exists but has no data")
                return nil
            }
            
            guard let accessToken = data["spotifyAccessToken"] as? String else {
                print("❌ Missing spotifyAccessToken in user document")
                return nil
            }
            
            guard let tokenExpiration = data["spotifyTokenExpiration"] as? Timestamp else {
                print("❌ Missing spotifyTokenExpiration in user document")
                return nil
            }
            
            guard let refreshToken = data["spotifyRefreshToken"] as? String else {
                print("❌ Missing spotifyRefreshToken in user document")
                return nil
            }
            
            print("✅ Successfully retrieved tokens")
            print("🕒 Token expires: \(tokenExpiration.dateValue())")
            print("⏱️ Current time: \(Date())")
            
            // Check if token is expired
            var currentToken = accessToken
            if tokenExpiration.dateValue() <= Date() {
                print("🔄 Token expired, refreshing...")
                if let newToken = await refreshSpotifyToken(userId: userId, refreshToken: refreshToken) {
                    currentToken = newToken
                    print("✅ Successfully refreshed token")
                } else {
                    print("❌ Failed to refresh token")
                    return nil
                }
            } else {
                print("✅ Token is still valid")
            }
            
            // Build the URL with query parameters
            var urlComponents = URLComponents(string: "https://api.spotify.com/v1/me/player/recently-played")!
            var queryItems = [URLQueryItem(name: "limit", value: "50")] // Max tracks to return
            
            if let after = after {
                queryItems.append(URLQueryItem(name: "after", value: String(after)))
            }
            
            urlComponents.queryItems = queryItems
            let apiURL = urlComponents.url!
            
            print("🌐 Making request to: \(apiURL.absoluteString)")
            
            // Now make your API request with the valid token
            var request = URLRequest(url: apiURL)
            request.setValue("Bearer \(currentToken)", forHTTPHeaderField: "Authorization")
            
            print("🚀 Sending request to Spotify API...")
            let (responseData, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Response status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    // Try to print response body for error details
                    if let errorJson = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] {
                        print("❌ Error response: \(errorJson)")
                    } else if let errorText = String(data: responseData, encoding: .utf8) {
                        print("❌ Error response text: \(errorText)")
                    }
                    return nil
                }
            }
            
            // Parse the response
            guard let json = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                print("❌ Failed to parse JSON response")
                if let responseString = String(data: responseData, encoding: .utf8) {
                    print("📝 Raw response: \(responseString)")
                }
                return nil
            }
            
            guard let items = json["items"] as? [[String: Any]] else {
                print("❌ No 'items' found in response")
                print("📝 Response keys: \(json.keys)")
                return nil
            }
            
            print("✅ Successfully parsed JSON with \(items.count) items")
            
            // Process tracks from the response
            var tracks: [SpotifyTrack] = []
            
            for (index, item) in items.enumerated() {
                guard let track = item["track"] as? [String: Any] else {
                    print("⚠️ Item \(index) missing 'track' property")
                    continue
                }
                
                guard let id = track["id"] as? String else {
                    print("⚠️ Track \(index) missing 'id'")
                    continue
                }
                
                guard let name = track["name"] as? String else {
                    print("⚠️ Track \(index) missing 'name'")
                    continue
                }
                
                guard let album = track["album"] as? [String: Any] else {
                    print("⚠️ Track \(index) missing 'album'")
                    continue
                }
                
                guard let albumName = album["name"] as? String else {
                    print("⚠️ Album missing 'name'")
                    continue
                }
                
                guard let artists = track["artists"] as? [[String: Any]] else {
                    print("⚠️ Track \(index) missing 'artists'")
                    continue
                }
                
                guard let playedAt = item["played_at"] as? String else {
                    print("⚠️ Item \(index) missing 'played_at'")
                    continue
                }
                
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
                
                tracks.append(spotifyTrack)
            }
            
            print("✅ Successfully processed \(tracks.count) tracks")
            return tracks
            
        } catch {
            print("❌ Error fetching Spotify data: \(error)")
            return nil
        }
    }
    
    // This is a placeholder for your refreshSpotifyToken function
    // You would need to implement this based on your existing code
    func refreshSpotifyToken(userId: String, refreshToken: String) async -> String? {
        print("🔄 Refreshing Spotify token...")
        
        // Spotify API token refresh endpoint
        let tokenURL = "https://accounts.spotify.com/api/token"
        
        // Your client ID and secret from your Spotify Developer account
        let clientId = "fa7a4a634c29432cb81412d1157e6d19"
        let clientSecret = "427745ea445b48a8b9588b92c7a18900" // In a real app, this should be secured
        
        var tokenRequest = URLRequest(url: URL(string: tokenURL)!)
        tokenRequest.httpMethod = "POST"
        tokenRequest.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Basic auth header required by Spotify
        let authString = "\(clientId):\(clientSecret)"
        if let authData = authString.data(using: .utf8) {
            let base64AuthString = authData.base64EncodedString()
            tokenRequest.setValue("Basic \(base64AuthString)", forHTTPHeaderField: "Authorization")
        }
        
        // Parameters for the token refresh
        let parameters = [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]
        
        let bodyString = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        tokenRequest.httpBody = bodyString.data(using: .utf8)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: tokenRequest)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🔄 Token refresh status code: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode != 200 {
                    if let errorText = String(data: data, encoding: .utf8) {
                        print("❌ Token refresh error: \(errorText)")
                    }
                    return nil
                }
            }
            
            if let tokenResponse = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let accessToken = tokenResponse["access_token"] as? String,
               let expiresIn = tokenResponse["expires_in"] as? Int {
                
                // Calculate new expiration date
                let expirationDate = Date().addingTimeInterval(TimeInterval(expiresIn))
                
                // Update user's Spotify tokens in Firestore
                try await firestoreManager.db.collection("users").document(userId).updateData([
                    "spotifyAccessToken": accessToken,
                    "spotifyTokenExpiration": Timestamp(date: expirationDate)
                ])
                
                print("✅ Successfully refreshed and stored new token. Expires in \(expiresIn) seconds")
                return accessToken
            } else {
                print("❌ Failed to parse token response")
                if let tokenResponseText = String(data: data, encoding: .utf8) {
                    print("📝 Raw token response: \(tokenResponseText)")
                }
                return nil
            }
        } catch {
            print("❌ Error refreshing token: \(error)")
            return nil
        }
    }
}



// Create the tester

