//
//  MapView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 2/17/25.
//
import SwiftUI
import MapKit
import Photos

class TrackingStateManager: ObservableObject {
    static let shared = TrackingStateManager()
    let locationService = LocationTrackingService.shared
    
    @Published var isTracking = false
    @Published var startTime: Date?
    @Published var elapsedTime: TimeInterval = 0.0
    @Published var currentRouteId: UUID?
    
    // Speed detection properties - now shared
    @Published var isVehicleStopped = true
    @Published var lastKnownSpeed: CLLocationSpeed = 0
    @Published var speedInMPH: Double = 0
    
    private var timer: Timer?
    private var stopDetectionTimer: Timer?
    
    private init() {}
    
    func startTracking(routeId: UUID, userID: String) {
        isTracking = true
        currentRouteId = routeId
        locationService.startTracking()
        locationService.initialize_route(routeID: routeId, userID: userID)
        startTime = Date()
        elapsedTime = 0.0
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.startTime else { return }
            self.elapsedTime = Date().timeIntervalSince(startTime)
        }
        
        // Start speed detection
        startSpeedDetection()
    }
    
    func stopTracking(userId: String, routeName: String, routeDescription: String) {
        guard let routeId = currentRouteId else { return }
        isTracking = false
        timer?.invalidate()
        timer = nil
        
        let finalTime = elapsedTime
        
        // Stop speed detection
        stopSpeedDetection()
        
        locationService.saveRoute(raw_userId: userId, time: finalTime, routeID: routeId, routeName: routeName, routeDescription: routeDescription) { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = 0.0
            self.locationService.stopTracking(userId: userId, routeID: routeId)
            self.currentRouteId = nil
        }
    }
    
    func cancelRoute(userId: String) {
        guard let routeId = currentRouteId else { return }
        isTracking = false
        timer?.invalidate()
        timer = nil
        
        // Stop speed detection
        stopSpeedDetection()
        
        print("Canceling route with ID: \(routeId)")
        
        // Delete the initialized route from database
        locationService.deleteRoute(userId: userId, routeID: routeId) { [weak self] in
            guard let self = self else { return }
            self.elapsedTime = 0.0
            self.locationService.stopTracking(userId: userId, routeID: routeId)
            self.currentRouteId = nil
            print("Route canceled and deleted successfully")
        }
    }
    
    // MARK: - Speed Detection Methods
    
    private func startSpeedDetection() {
        isVehicleStopped = true
        lastKnownSpeed = 0
        speedInMPH = 0
        stopDetectionTimer?.invalidate()
        
        // Check every 2 seconds
        stopDetectionTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateStopDetection()
        }
        
        print("Speed detection started")
    }
    
    private func stopSpeedDetection() {
        stopDetectionTimer?.invalidate()
        stopDetectionTimer = nil
        isVehicleStopped = false
        lastKnownSpeed = 0
        speedInMPH = 0
        
        print("Speed detection stopped")
    }
    
    private func updateStopDetection() {
        guard isTracking,
              let lastLocation = locationService.locations.last else {
            print("Speed detection: No tracking or location data")
            return
        }
        
        // Get speed from location (in m/s)
        lastKnownSpeed = max(0, lastLocation.speed) // Ensure non-negative
        speedInMPH = lastKnownSpeed * 2.237 // Convert to MPH
        
        print("Speed detection: \(String(format: "%.1f", speedInMPH)) mph, accuracy: \(lastLocation.horizontalAccuracy)m")
        
        // Consider stopped if speed is less than 1.34 m/s (3 mph) and GPS accuracy is reasonable
        let speedThreshold: CLLocationSpeed = 1.34 // 3 mph in m/s
        let isCurrentlySlow = lastKnownSpeed < speedThreshold && lastLocation.horizontalAccuracy < 20
        
        // Simple state management
        if isCurrentlySlow && !isVehicleStopped {
            // Just became slow/stopped - wait 8 seconds to confirm
            print("Vehicle slowing down, waiting 8 seconds to confirm stop...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) { [weak self] in
                // Double-check we're still slow after 8 seconds
                guard let self = self,
                      let currentLocation = self.locationService.locations.last else { return }
                
                if currentLocation.speed < speedThreshold {
                    DispatchQueue.main.async {
                        self.isVehicleStopped = true
                        print("✅ Vehicle confirmed as STOPPED - Camera enabled")
                    }
                }
            }
        } else if !isCurrentlySlow && isVehicleStopped {
            // Started moving again
            DispatchQueue.main.async { [weak self] in
                self?.isVehicleStopped = false
                print("🚗 Vehicle detected as MOVING - Camera disabled")
            }
        }
    }
}

// MARK: - Route Details Overlay with Cancel Route Option
struct RouteDetailsOverlay: View {
    @State private var routeName: String = ""
    @State private var routeDescription: String = ""
    @State private var showCancelConfirmation = false
    @Environment(\.colorScheme) var colorScheme
    let onSave: (String, String) -> Void
    let onCancel: () -> Void
    let onCancelRoute: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Save Your Route")
                .font(.headline)
                .padding(.top, 20)
            
            // Divider
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3))
                .padding(.horizontal)
            
            // Form fields
            VStack(alignment: .leading, spacing: 12) {
                Text("Route Name")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField("Enter a name", text: $routeName)
                    .padding()
                    .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                Text("Description (Optional)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                
                TextEditor(text: $routeDescription)
                    .frame(height: 100)
                    .padding(4)
                    .background(colorScheme == .dark ? Color.black.opacity(0.3) : Color.white.opacity(0.8))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            
            // Buttons
            VStack(spacing: 12) {
                // Primary action buttons (Save and Cancel)
                HStack(spacing: 20) {
                    Button(action: onCancel) {
                        Text("Cancel")
                            .frame(minWidth: 100)
                            .padding()
                            .background(Color.gray.opacity(0.3))
                            .foregroundColor(colorScheme == .dark ? .white : .black)
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        onSave(routeName, routeDescription)
                    }) {
                        Text("Save Route")
                            .frame(minWidth: 100)
                            .padding()
                            .background(routeName.isEmpty ? Color.blue.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(routeName.isEmpty)
                }
                
                // Cancel Route button (destructive action)
                Button(action: {
                    showCancelConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                            .font(.caption)
                        Text("Cancel Route")
                            .font(.subheadline)
                    }
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.red.opacity(0.5), lineWidth: 1)
                    )
                }
            }
            .padding(.bottom, 20)
        }
        .frame(width: UIScreen.main.bounds.width * 0.85)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(colorScheme == .dark ? Color.black.opacity(0.95) : Color.white.opacity(0.95))
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.2), radius: 10)
        .alert("Cancel Route?", isPresented: $showCancelConfirmation) {
            Button("Keep Route", role: .cancel) { }
            Button("Cancel Route", role: .destructive) {
                onCancelRoute()
            }
        } message: {
            Text("This will permanently delete your route and all associated data. This action cannot be undone.")
        }
    }
}

// MARK: - Tracking Overlay View
struct TrackingOverlayView: View {
    @StateObject private var locationService = LocationTrackingService.shared
    @StateObject private var trackingManager = TrackingStateManager.shared
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    @State private var showRouteDetailsOverlay = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Full-width tracking bar at bottom
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 0) {
                        // Top section with main controls
                        HStack {
                            // Stop/Finish button
                            Button(action: {
                                showRouteDetailsOverlay = true
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: "stop.fill")
                                        .font(.title2)
                                    Text("FINISH")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.red)
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Speed display in the middle when moving
                            if trackingManager.isTracking && !trackingManager.isVehicleStopped {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 2) {
                                        Text(String(format: "%.0f", trackingManager.speedInMPH))
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("mph")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                }
                                .transition(.opacity.combined(with: .scale))
                            } else {
                                Spacer()
                            }
                            
                            // Camera button - only when stopped
                            if trackingManager.isVehicleStopped {
                                Button(action: {
                                    showCamera = true
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: "camera.fill")
                                            .font(.title2)
                                        Text("PHOTO")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .frame(width: 80, height: 60)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .transition(.scale.combined(with: .opacity))
                            } else {
                                // Show disabled camera button for visual consistency
                                VStack(spacing: 4) {
                                    Image(systemName: "camera.fill")
                                        .font(.title2)
                                    Text("PHOTO")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                }
                                .frame(width: 80, height: 60)
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(.white.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        
                        // Metrics bar
                        HStack {
                            // Time
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TIME")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .fontWeight(.medium)
                                Text(formatTimeInterval(trackingManager.elapsedTime))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Distance
                            VStack(alignment: .center, spacing: 2) {
                                Text("DISTANCE")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .fontWeight(.medium)
                                Text(String(format: "%.2f mi", locationService.totalDistance * 0.00062137))
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            }
                            
                            Spacer()
                            
                            // Status
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("STATUS")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .fontWeight(.medium)
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(trackingManager.isVehicleStopped ? Color.red : Color.green)
                                        .frame(width: 8, height: 8)
                                    Text(trackingManager.isVehicleStopped ? "STOPPED" : "MOVING")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(trackingManager.isVehicleStopped ? .red : .green)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity)
                    .background(
                        LinearGradient(
                            colors: [Color.black.opacity(0.9), Color.black.opacity(0.95)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1),
                        alignment: .top
                    )
                    .frame(height: 180 + geometry.safeAreaInsets.bottom)
                    .animation(.easeInOut(duration: 0.3), value: trackingManager.isVehicleStopped)
                }
                
                // Route Details Overlay - simpler approach
                if showRouteDetailsOverlay {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showRouteDetailsOverlay = false
                        }
                    
                    RouteDetailsOverlay(
                        onSave: { name, description in
                            trackingManager.stopTracking(
                                userId: authManager.userId ?? "",
                                routeName: name,
                                routeDescription: description
                            )
                            showRouteDetailsOverlay = false
                        },
                        onCancel: {
                            showRouteDetailsOverlay = false
                        },
                        onCancelRoute: {
                            trackingManager.cancelRoute(userId: authManager.userId ?? "")
                            showRouteDetailsOverlay = false
                        }
                    )
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .transition(.scale.combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showRouteDetailsOverlay)
                }
            }
        }
        .sheet(isPresented: $showCamera, onDismiss: handleCameraDismiss) {
            CameraView(image: $capturedImage)
        }
    }
    
    private func handleCameraDismiss() {
        guard let capturedImage = capturedImage,
              let currentRouteId = trackingManager.currentRouteId else {
            return
        }
        
        uploadImageWithRetry(image: capturedImage, routeId: currentRouteId)
    }

    private func uploadImageWithRetry(image: UIImage, routeId: UUID, attempt: Int = 1) {
        let maxRetries = 4
        
        Task {
            do {
                let imageURL = try await uploadImageToS3(
                    image: image,
                    bucketName: "cartrekk-images"
                )
                
                DispatchQueue.main.async {
                    self.locationService.addImageToRoute(routeID: routeId, imageURL: imageURL)
                }
                
            } catch {
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt - 1))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.uploadImageWithRetry(image: image, routeId: routeId, attempt: attempt + 1)
                    }
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

// MARK: - MapView
struct MapView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject private var locationService = LocationTrackingService.shared
    @StateObject private var trackingManager = TrackingStateManager.shared
    
    
    //@StateObject private var awsService = AWSService.shared
    
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var showCamera = false
    @State private var capturedImage: UIImage?
    
    var body: some View {
        guard let userId = authManager.userId else {
            return AnyView(Text("Please log in to track routes.")
                .foregroundColor(.white)
                .font(.title2)
                .padding()
                .background(Color.black.edgesIgnoringSafeArea(.all)))
        }

        return AnyView(
            GeometryReader { geometry in
                ZStack {
                    // Main Map View - always full screen
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        if !locationService.locations.isEmpty {
                            MapPolyline(coordinates: locationService.locations.map { $0.coordinate })
                                .stroke(.blue, lineWidth: 3)
                        }
                    }
                    .mapControls {
                        // Keep compass and scale, but hide user location button
                        MapCompass()
                        MapScaleView()
                    }
                    .mapControlVisibility(.hidden) // Hide default user location button
                    .ignoresSafeArea(.all)
                    
                    // Custom positioned map controls
                    VStack {
                        Spacer()
                        
                        HStack {
                            Spacer()
                            // Custom recenter button - positioned bottom left
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    cameraPosition = .userLocation(fallback: .automatic)
                                }
                            }) {
                                Image(systemName: "location.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                    .frame(width: 44, height: 44)
                                    .background(Color.white.opacity(0.9))
                                    .clipShape(Circle())
                                    .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                            }
                            .padding(.leading, 20)
                            .padding(.bottom, trackingManager.isTracking ? 200 : 120) // Adjust for tracking overlay
                            .padding(.trailing, 10)
                            
                        }
                    }
                    
                    // Only show start overlay when NOT tracking
                    if !trackingManager.isTracking {
                        defaultOverlay(geometry: geometry)
                    }
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
    
    // MARK: - Default Overlay (Start Screen)
    private func defaultOverlay(geometry: GeometryProxy) -> some View {
        VStack {
            Spacer()
            Spacer()
            Spacer()
            
            // Compact stats when not tracking
            VStack {
                Text("Ready to Track")
                    .font(.title2)
                    .bold()
                    .foregroundColor(.white)
                Text("Tap to start your route")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Spacer()
                .frame(height: 20)
            
            // Start button
            HStack {
                Spacer()
                
                Button(action: {
                    CLLocationManager().requestAlwaysAuthorization()
                    let newRouteId = UUID()
                    trackingManager.startTracking(routeId: newRouteId, userID: userId)
                }) {
                    VStack {
                        Image(systemName: "car.fill")
                            .resizable()
                            .frame(width: 40, height: 32)
                        Text("START")
                            .font(.caption)
                            .fontWeight(.bold)
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(Circle())
                    .shadow(radius: 10)
                }
                
                Spacer()
            }
            .padding(.bottom, 10)
        }
    }
    
    private var userId: String {
        return authManager.userId ?? ""
    }
    
    private func handleCameraDismiss() {
        guard let capturedImage = capturedImage,
              let currentRouteId = trackingManager.currentRouteId else {
            return
        }
        
        uploadImageWithRetry(image: capturedImage, routeId: currentRouteId)
    }

    private func uploadImageWithRetry(image: UIImage, routeId: UUID, attempt: Int = 1) {
        let maxRetries = 4
        
        Task {
            do {
//                let imageURL = try await uploadImageToS3(
//                    image: image,
//                    bucketName: "cartrekk-images"
//                )
                
                
                
                
                
                let imageURL = try await AWSService.shared.uploadImageToS3(image: image)
                // Upload successful

                DispatchQueue.main.async {
                    self.locationService.addImageToRoute(routeID: routeId, imageURL: imageURL)
                }
                
            } catch {
                if attempt < maxRetries {
                    let delay = pow(2.0, Double(attempt - 1))
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.uploadImageWithRetry(image: image, routeId: routeId, attempt: attempt + 1)
                    }
                }
            }
        }
    }
}

// MARK: - Notification Extension
extension Notification.Name {
    static let locationUpdated = Notification.Name("locationUpdated")
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.originalImage] as? UIImage {
                parent.image = selectedImage
                
                // Save to camera roll
                saveImageToCameraRoll(selectedImage)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
        
        private func saveImageToCameraRoll(_ image: UIImage) {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAsset(from: image)
                    }) { success, error in
                        DispatchQueue.main.async {
                            if success {
                                print("Image saved to camera roll successfully")
                            } else if let error = error {
                                print("Error saving image to camera roll: \(error.localizedDescription)")
                            }
                        }
                    }
                case .denied, .restricted:
                    print("Photo library access denied")
                case .notDetermined:
                    print("Photo library access not determined")
                @unknown default:
                    print("Unknown photo library authorization status")
                }
            }
        }
    }
}
