//
//  LocationTrackingService.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 2/8/25.
//

import Foundation
import CoreLocation
import MapKit
import SwiftUI
import Polyline
import FirebaseCore
import FirebaseAuth

class LocationTrackingService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationTrackingService()
    @Published var locations: [CLLocation] = []
    @Published var isTracking = false
    @Published var totalDistance = 0.0
    let spotifyManager = SpotifyFuncManager()
    
    private let locationManager: CLLocationManager
    //private let distanceFilter: Double = 10
    private let timeInterval: TimeInterval = 2
    let firestoreManager = FirestoreManager.shared
    private var routeStartTimestamp: Int64?
    private var trackedSongs: [SpotifyTrack] = []
    
    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        //locationManager.distanceFilter = distanceFilter
        
        locationManager.allowsBackgroundLocationUpdates = true // Requires background capability
        //locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startTracking() {
        locations.removeAll()
        isTracking = true
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
        
        // Start Spotify tracking if user is connected
        routeStartTimestamp = Int64(Date().timeIntervalSince1970 * 1000) // Milliseconds
        trackedSongs = []
        
      
        print("Current timestamp: \(Date().timeIntervalSince1970 * 1000)")
        print("Route start timestamp: \(routeStartTimestamp)")
        
    }
    
    func stopTracking(userId: String, routeID: UUID) {
        isTracking = false
          
        FirestoreManager.shared.incrementUserTotalDistance(
            userId: userId,
            additionalDistance: totalDistance * 0.000621371
        ) { error in
            if let error = error {
                print("Failed to update total distance: \(error)")
            } else {
                print("Successfully updated total distance")
            }
        }
        
        if let userId = Auth.auth().currentUser?.uid, let timestamp = routeStartTimestamp {
            Task {
                let spotifyTracks = await spotifyManager.fetchSongsFromSpotify(userId: userId, afterTimestamp: timestamp)
                print("Fetched \(spotifyTracks.count) songs from Spotify")
                
                if !spotifyTracks.isEmpty {
                    FirestoreManager.shared.saveSpotifySongsToRoute(routeID: routeID, songs: spotifyTracks) { error in
                        if let error = error {
                            print("Error saving Spotify songs to route: \(error)")
                        } else {
                            print("Successfully saved \(spotifyTracks.count) Spotify songs to route")
                        }
                    }
                }
            }
        }else {
            print("Cannot fetch Spotify songs: userId or timestamp is nil")
        }
        
        totalDistance = 0.0
        print("resetting distance")
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
        guard isTracking, let location = newLocations.last else { return }
        
        // Only add location if enough time has passed since the last update
        if let lastLocation = locations.last {
            let timeSinceLastUpdate = location.timestamp.timeIntervalSince(lastLocation.timestamp)
            if timeSinceLastUpdate >= timeInterval {
                let distance = location.distance(from: lastLocation) // Returns distance in meters
                totalDistance += distance // Add to total distance
                //print(totalDistance)
                locations.append(location)
            }
        } else {
            // First location
            locations.append(location)
        }
        
        NotificationCenter.default.post(name: .locationUpdated, object: nil)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    // MARK: - Route Data Management
    func saveRoute(raw_userId: String, time: TimeInterval, routeID: UUID, routeName: String, routeDescription: String, completion: @escaping () -> Void) {
        let routeId = routeID.uuidString
        
        FirestoreManager.shared.db.collection("routes").document(routeId).getDocument { [weak self] (document, error) in
            guard let self = self else {
                completion()
                return
            }
            
            let existingImages = document?.data()?["routeImages"] as? [String] ?? []
            
            let distance = self.totalDistance * 0.00062137
            print(distance)
            let duration = time
            let likes = 0
            let polyline = Polyline(locations: self.locations)
            let encodedPolyline: String = polyline.encodedPolyline
            let isPublic = false
            let userId = raw_userId
            
            // Save to Firebase with existing images
            FirestoreManager.shared.saveRouteDetails(
                routeId: routeId,
                distance: distance,
                duration: duration,
                likes: likes,
                polyline: encodedPolyline,
                isPublic: isPublic,
                routeImages: existingImages,
                userId: userId,
                routeName: routeName,
                routeDescription: routeDescription
            ) { [weak self] in
                completion()  // Call completion after save is done
            }
        }
    }
    
    func initialize_route(routeID: UUID?, userID: String) {
        let route_id = routeID!.uuidString
        FirestoreManager.shared.saveRouteDetails(
            routeId: route_id,
            distance: 0,
            duration: 0.0,
            likes: 0,
            polyline: "",
            isPublic: false,
            routeImages: nil,
            userId: userID,
            routeName: "",
            routeDescription: ""
            
        ) {

        }
    }
    
    func deleteRoute(userId: String, routeID: UUID, completion: @escaping () -> Void) {
        firestoreManager.deleteRoute(routeId: routeID.uuidString) { success in
            DispatchQueue.main.async {
                if success {
                    print("Successfully deleted route")
                } else {
                    print("Error deleting route")
                }
                completion() 
            }
        }
    }
    
    func addImageToRoute(routeID: UUID?, imageURL: String) {
        guard let route_id = routeID?.uuidString else {
            print("Invalid route ID")
            return
        }
        
        let routeRef = FirestoreManager.shared.db.collection("routes").document(route_id)
        
        routeRef.getDocument { (document, error) in
            if let error = error {
                print("Error getting document: \(error)")
                return
            }
            
            guard let document = document, document.exists,
                  var data = document.data() else {
                print("Document does not exist or is empty")
                return
            }
            
            // Get current routeImages array or create empty one
            var currentImages = data["routeImages"] as? [String] ?? []
            
            // Append new image URL
            currentImages.append(imageURL)
            
            FirestoreManager.shared.updateRouteImages(routeId: route_id, newImageUrl: imageURL) {_ in }
            
        }
    }
}
