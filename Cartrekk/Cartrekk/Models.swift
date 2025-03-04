//
//  Models.swift
//  Cartrekk
//
//  Created by Sahil Tallam on 2/15/25.
//

import Foundation
import CoreLocation

struct Post: Identifiable {
    let id: String
    var route: Route
    var photos: [String]
    var likes: Int
    var comments: [Comment]
    var polyline: String
    var userid: String
    var username: String
    var name: String
    var description: String
    var distance: Double
    var duration: Double
}

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

struct Comment: Identifiable {
    let id: String
    let userId: String
    let username: String
    let text: String
    let timestamp: Date
}


