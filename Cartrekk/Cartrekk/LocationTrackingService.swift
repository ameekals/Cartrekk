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

class LocationTrackingService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var locations: [CLLocation] = []
    @Published var isTracking = false
    @Published var totalDistance = 0.0
    
    private let locationManager: CLLocationManager
    private let distanceFilter: Double = 10
    private let timeInterval: TimeInterval = 2
    
    init(locationManager: CLLocationManager = CLLocationManager()) {
        self.locationManager = locationManager
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = distanceFilter
        
        locationManager.allowsBackgroundLocationUpdates = true // Requires background capability
        //locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startTracking() {
        locations.removeAll()
        isTracking = true
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func stopTracking() {
        isTracking = false
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
                locations.append(location)
            }
        } else {
            // First location
            locations.append(location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager failed with error: \(error.localizedDescription)")
    }
    
    // MARK: - Route Data Management
    func saveRoute(raw_userId: String, time: TimeInterval) -> Route {
        let route = Route(
            id: UUID(),
            date: Date(),
            coordinates: locations.map {
                RouteCoordinate(
                    latitude: $0.coordinate.latitude,
                    longitude: $0.coordinate.longitude,
                    timestamp: $0.timestamp
                )
            }
        )
        let routeId = route.id.uuidString
        let distance = totalDistance * 0.00062137
        let duration = time
        let likes = 0
        let polyline = Polyline(locations: locations)
        let encodedPolyline: String = polyline.encodedPolyline
        let isPublic = true
        let routeImages: [String]? = nil
        let userId = raw_userId
        
        // Here you would typically save to persistent storage
        FirestoreManager.shared.saveRouteDetails(routeId: routeId,
                         distance: distance,
                         duration: duration,
                         likes: likes,
                         polyline: encodedPolyline,
                         isPublic: isPublic,
                         routeImages: routeImages,
                         userId: userId)
        return route
    }
}

// MARK: - Data Models

