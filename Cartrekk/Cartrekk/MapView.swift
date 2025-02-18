//
//  MapView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 2/17/25.
//
import SwiftUI
import MapKit


class TrackingStateManager: ObservableObject {
    static let shared = TrackingStateManager()
    let locationService = LocationTrackingService.shared
    
    @Published var isTracking = false
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0.0
    @Published var currentRouteId: UUID? // Add this to store the current route ID
    private var timer: Timer?
    
    private init() {}
    
    func startTracking(routeId: UUID) { // Modify to accept routeId
        isTracking = true
        currentRouteId = routeId // Store the route ID
        locationService.startTracking()
        locationService.initialize_route(routeID: routeId) // Initialize with the same ID
        startTime = Date()
        elapsedTime = 0.0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }
    
    func stopTracking(userId: String) {
        guard let routeId = currentRouteId else { return } // Use the stored route ID
        isTracking = false
        timer?.invalidate()
        timer = nil
        locationService.saveRoute(raw_userId: userId, time: elapsedTime, routeID: routeId)
        elapsedTime = 0.0
        currentRouteId = nil // Clear the route ID
    }
}


// MARK: - Map View
// Modified MapView
struct MapView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var locationService = LocationTrackingService.shared
    @StateObject private var trackingManager = TrackingStateManager.shared
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        let UUid: String = authManager.userId!
        VStack {
            Map(position: $cameraPosition) {
                UserAnnotation()
                
                if !locationService.locations.isEmpty {
                    MapPolyline(coordinates: locationService.locations.map { $0.coordinate })
                        .stroke(.blue, lineWidth: 3)
                }
            }
            
            VStack {
                Text(formatTimeInterval(trackingManager.elapsedTime))
                    .font(.title2)
                    .bold()
                Text(String(format: "%.2f mi", locationService.totalDistance * 0.00062137))
                    .font(.headline)
            }
            .padding()
            
            HStack {
                Spacer()
                Spacer(minLength: 80)
                
                Button(action: {
                    if trackingManager.isTracking {
                        trackingManager.stopTracking(userId: UUid)
                        locationService.stopTracking()
                    } else {
                        CLLocationManager().requestAlwaysAuthorization()
                        let newRouteId = UUID() // Generate new route ID
                        trackingManager.startTracking(routeId: newRouteId) // Pass it to tracking manager
                    }
                }) {
                    Text(trackingManager.isTracking ? "Stop Tracking" : "Start Tracking")
                        .padding()
                        .background(trackingManager.isTracking ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                Spacer()
                Button(action: {
                    showCamera = true
                }) {
                    Image(systemName: "camera.circle.fill")
                        .resizable()
                        .frame(width: 30, height: 30)
                        .foregroundColor(.white)
                        .background(Color.blue.opacity(0.9))
                        .clipShape(Circle())
                }
                Spacer()
            }
        }
        .onAppear {
            CLLocationManager().requestWhenInUseAuthorization()
            CLLocationManager().requestAlwaysAuthorization()
        }
        .sheet(isPresented: $showCamera, onDismiss: handleCameraDismiss){
            CameraView(image: $capturedImage)
        }
    }
    
    private func handleCameraDismiss() {
        if let capturedImage = capturedImage,
           let currentRouteId = trackingManager.currentRouteId { // Get the current route ID
            Task {
                do {
                    let imageURL = try await uploadImageToS3(image: capturedImage,
                                                           imageName: "capturedImage.jpg",
                                                           bucketName: "cartrekk-images")
                   
                    locationService.addImageToRoute(routeID: currentRouteId, imageURL: imageURL)
                    
                    print("Image uploaded to S3: \(imageURL)")
                } catch {
                    print("Upload failed: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = Int(interval) / 60 % 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
