//
//  CartrekkTests_tv.swift
//  CartrekkTests_tv
//
//  Created by Tejas Vaze on 2/8/25.
//

import XCTest
import CoreLocation
@testable import Cartrekk  // Make sure this matches your app's target name

final class LocationTrackingServiceTests: XCTestCase {
    var locationService: LocationTrackingService!
    var mockLocationManager: MockCLLocationManager!
    
    override func setUp() {
        super.setUp()
        mockLocationManager = MockCLLocationManager()
        locationService = LocationTrackingService(locationManager: mockLocationManager)
    }
    
    override func tearDown() {
        locationService = nil
        mockLocationManager = nil
        super.tearDown()
    }
    
    func testInitialState() {
        XCTAssertFalse(locationService.isTracking)
        XCTAssertTrue(locationService.locations.isEmpty)
    }
    
    func testStartTracking() {
        locationService.startTracking()
        XCTAssertTrue(locationService.isTracking)
        XCTAssertTrue(mockLocationManager.startUpdatingLocationCalled)
    }
    
    func testStopTracking() {
        locationService.startTracking()
        locationService.stopTracking()
        XCTAssertFalse(locationService.isTracking)
        XCTAssertTrue(mockLocationManager.stopUpdatingLocationCalled)
    }
    
    func testLocationUpdate() {
        locationService.startTracking()
        
        let location1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.3308, longitude: -122.0074),
            altitude: CLLocationDistance(50),
            horizontalAccuracy: 90,
            verticalAccuracy: 90,
            timestamp: Date()
        )
        
        locationService.locationManager(mockLocationManager, didUpdateLocations: [location1])
        XCTAssertEqual(locationService.locations.count, 1)
        
        // Wait 6 seconds (more than our timeInterval) and add another location
        Thread.sleep(forTimeInterval: 6)
        
        let location2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0084),
            altitude: CLLocationDistance(50),
            horizontalAccuracy: 90,
            verticalAccuracy: 90,
            timestamp: Date()
        )
        
        locationService.locationManager(mockLocationManager, didUpdateLocations: [location2])
        XCTAssertEqual(locationService.locations.count, 2)
    }
    
    func testRouteCreation() {
        locationService.startTracking()
        
        let locations = [
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.3308, longitude: -122.0074),
                       altitude: CLLocationDistance(50),
                       horizontalAccuracy: 90,
                       verticalAccuracy: 90,
                       timestamp: Date()),
            CLLocation(coordinate: CLLocationCoordinate2D(latitude: 37.3318, longitude: -122.0084),
                       altitude: CLLocationDistance(50),
                       horizontalAccuracy: 90,
                       verticalAccuracy: 90,
                       timestamp: Date().addingTimeInterval(10))
        ]
        
        for location in locations {
            locationService.locationManager(mockLocationManager, didUpdateLocations: [location])
        }
        
        let route = locationService.saveRoute()
        XCTAssertEqual(route.coordinates.count, 2)
        XCTAssertGreaterThan(route.distance, 0)
    }
}

// MARK: - Mock CLLocationManager
class MockCLLocationManager: CLLocationManager {
    var startUpdatingLocationCalled = false
    var stopUpdatingLocationCalled = false
    
    override func startUpdatingLocation() {
        startUpdatingLocationCalled = true
    }
    
    override func stopUpdatingLocation() {
        stopUpdatingLocationCalled = true
    }
}
