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
        //locationManager.allowsBackgroundLocationUpdates = true // Requires background capability
        //locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func startTracking() {
        locations.removeAll()
        isTracking = true
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
    func saveRoute() -> Route {
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
        let distance = totalDistance
        let duration = 70.0
        let likes = 0
        let polyline = Polyline(locations: locations)
        let encodedPolyline: String = polyline.encodedPolyline
        let isPublic = true
        let routeImages: [String]? = nil
        let userId = "preet"
        
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
struct Route: Identifiable, Codable {
    let id: UUID
    let date: Date
    let coordinates: [RouteCoordinate]
    
    var distance: Double {
        guard coordinates.count > 1 else { return 0 }
        
        var totalDistance = 0.0
        for i in 0..<coordinates.count-1 {
            let start = CLLocation(
                latitude: coordinates[i].latitude,
                longitude: coordinates[i].longitude
            )
            let end = CLLocation(
                latitude: coordinates[i+1].latitude,
                longitude: coordinates[i+1].longitude
            )
            totalDistance += end.distance(from: start)
        }
        return totalDistance
    }
}

struct RouteCoordinate: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
}
