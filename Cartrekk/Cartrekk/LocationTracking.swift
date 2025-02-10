//
//  LocationTracking.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 2/1/25.
//

//import Foundation
//import CoreLocation
//import MapKit
//
//class LocationTrackingService: NSObject, ObservableObject, CLLocationManagerDelegate {
//    @Published var locations: [CLLocation] = []
//    @Published var isTracking = false
//    
//    private let locationManager = CLLocationManager()
//    private let distanceFilter: Double = 10 // Update every 10 meters
//    private let timeInterval: TimeInterval = 5 // Update every 5 seconds
//    
//    override init() {
//        super.init()
//        setupLocationManager()
//    }
//    
//    private func setupLocationManager() {
//        locationManager.delegate = self
//        locationManager.desiredAccuracy = kCLLocationAccuracyBest
//        locationManager.distanceFilter = distanceFilter
//        locationManager.allowsBackgroundLocationUpdates = true // Requires background capability
//        locationManager.pausesLocationUpdatesAutomatically = false
//    }
//    
//    func startTracking() {
//        locations.removeAll()
//        isTracking = true
//        locationManager.startUpdatingLocation()
//    }
//    
//    func stopTracking() {
//        isTracking = false
//        locationManager.stopUpdatingLocation()
//    }
//    
//    // MARK: - CLLocationManagerDelegate
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations newLocations: [CLLocation]) {
//        guard isTracking, let location = newLocations.last else { return }
//        
//        // Only add location if enough time has passed since the last update
//        if let lastLocation = locations.last {
//            let timeSinceLastUpdate = location.timestamp.timeIntervalSince(lastLocation.timestamp)
//            if timeSinceLastUpdate >= timeInterval {
//                locations.append(location)
//            }
//        } else {
//            // First location
//            locations.append(location)
//        }
//    }
//    
//    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
//        print("Location manager failed with error: \(error.localizedDescription)")
//    }
//    
//    // MARK: - Route Data Management
//    func saveRoute() -> Route {
//        let route = Route(
//            id: UUID(),
//            date: Date(),
//            coordinates: locations.map {
//                RouteCoordinate(
//                    latitude: $0.coordinate.latitude,
//                    longitude: $0.coordinate.longitude,
//                    timestamp: $0.timestamp
//                )
//            }
//        )
//        // Here you would typically save to persistent storage
//        return route
//    }
//}
//
//// MARK: - Data Models
//struct Route: Identifiable, Codable {
//    let id: UUID
//    let date: Date
//    let coordinates: [RouteCoordinate]
//    
//    var distance: Double {
//        guard coordinates.count > 1 else { return 0 }
//        
//        var totalDistance = 0.0
//        for i in 0..<coordinates.count-1 {
//            let start = CLLocation(
//                latitude: coordinates[i].latitude,
//                longitude: coordinates[i].longitude
//            )
//            let end = CLLocation(
//                latitude: coordinates[i+1].latitude,
//                longitude: coordinates[i+1].longitude
//            )
//            totalDistance += end.distance(from: start)
//        }
//        return totalDistance
//    }
//}
//
//struct RouteCoordinate: Codable {
//    let latitude: Double
//    let longitude: Double
//    let timestamp: Date
//}
