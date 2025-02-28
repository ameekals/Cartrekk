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
    @Published var currentRouteId: UUID?
    private var timer: Timer?
    
    private init() {}
    

    func startTracking(routeId: UUID, userID: String) { // Modify to accept routeId
        isTracking = true
        currentRouteId = routeId
        locationService.startTracking()
        locationService.initialize_route(routeID: routeId, userID: userID) // Initialize with the same ID
        startTime = Date()
        elapsedTime = 0.0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
    }
    
    func stopTracking(userId: String) {
        guard let routeId = currentRouteId else { return }
        isTracking = false
        timer?.invalidate()
        timer = nil
        
        let finalTime = elapsedTime
        
        locationService.saveRoute(raw_userId: userId, time: finalTime, routeID: routeId) { [weak self] in

            guard let self = self else { return }
            self.elapsedTime = 0.0
            self.locationService.stopTracking(userId: userId)
            self.currentRouteId = nil
        }
    }
}

// MARK: - Map View
struct MapView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var locationService = LocationTrackingService.shared
    @StateObject private var trackingManager = TrackingStateManager.shared
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        // Use optional binding instead of force-unwrapping (!)
        guard let userId = authManager.userId else {
            return AnyView(Text("Please log in to track routes.")
                .foregroundColor(.white)
                .font(.title2)
                .padding()
                .background(Color.black.edgesIgnoringSafeArea(.all)))
        }

        return AnyView(
            ZStack {
                Map(position: $cameraPosition) {
                    UserAnnotation()
                    if !locationService.locations.isEmpty {
                        MapPolyline(coordinates: locationService.locations.map { $0.coordinate })
                            .stroke(.blue, lineWidth: 3)

                    }
                }
                .edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()

                    VStack {
                        Text(formatTimeInterval(trackingManager.elapsedTime))
                            .font(.title2)
                            .bold()
                            .foregroundColor(.white)
                        Text(String(format: "%.2f mi", locationService.totalDistance * 0.00062137))
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    HStack {
                        Spacer()

                        Button(action: {
                            if trackingManager.isTracking {
                                print("Stopping Route")
                                trackingManager.stopTracking(userId: userId)
                            } else {
                                CLLocationManager().requestAlwaysAuthorization()
                                let newRouteId = UUID()
                                trackingManager.startTracking(routeId: newRouteId, userID: userId)
                            }
                        }) {
                            Image(systemName: "car.fill")
                                .resizable()
                                .frame(width: 60, height: 50)
                                .padding()
                                .background(trackingManager.isTracking ? Color.red : Color.green)
                                .foregroundColor(.white)
                                .clipShape(Circle())
                                .shadow(radius: 10)
                        }

                        Spacer()

                        if trackingManager.isTracking {
                           Button(action: {
                               showCamera = true
                           }) {
                               Image(systemName: "camera.circle.fill")
                                   .resizable()
                                   .frame(width: 50, height: 50)
                                   .foregroundColor(.white)
                                   .background(Color.blue.opacity(0.9))
                                   .clipShape(Circle())
                                   .shadow(radius: 5)
                           }
                           
                           Spacer()
                       }
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .onAppear {
                CLLocationManager().requestWhenInUseAuthorization()
                CLLocationManager().requestAlwaysAuthorization()
            }
            .sheet(isPresented: $showCamera, onDismiss: handleCameraDismiss) {
                CameraView(image: $capturedImage)
            }
        )
    }
    
    private func handleCameraDismiss() {
        if let capturedImage = capturedImage,
           let currentRouteId = trackingManager.currentRouteId {
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
