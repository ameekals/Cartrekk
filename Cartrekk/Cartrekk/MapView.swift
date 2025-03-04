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
    
    func stopTracking(userId: String, routeName: String, routeDescription: String) {
        guard let routeId = currentRouteId else { return }
        isTracking = false
        timer?.invalidate()
        timer = nil
        
        let finalTime = elapsedTime
        
        locationService.saveRoute(raw_userId: userId, time: finalTime, routeID: routeId, routeName: routeName, routeDescription: routeDescription) { [weak self] in

            guard let self = self else { return }
            self.elapsedTime = 0.0
            self.locationService.stopTracking(userId: userId)
            self.currentRouteId = nil
        }
    }
}

struct RouteDetailsOverlay: View {
    @Binding var isPresented: Bool
    @State private var routeName: String = ""
    @State private var routeDescription: String = ""
    @Environment(\.colorScheme) var colorScheme
    var onSave: (String, String) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            if isPresented {
                // Just the card with no background layer
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
                    HStack(spacing: 20) {
                        Button(action: {
                            isPresented = false
                        }) {
                            Text("Cancel")
                                .frame(minWidth: 100)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                                .cornerRadius(10)
                        }
                        
                        Button(action: {
                            onSave(routeName, routeDescription)
                            isPresented = false
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
                    .padding(.bottom, 20)
                }
                .frame(width: UIScreen.main.bounds.width * 0.85)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(colorScheme == .dark ? Color.black.opacity(0.95) : Color.white.opacity(0.95))
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: Color.black.opacity(0.2), radius: 10)
                .transition(.opacity)
                .animation(.easeIn(duration: 0.2), value: isPresented)
                // Center it on screen
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .zIndex(100)
            }
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
    @State private var showRouteDetailsOverlay = false
    
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
                VStack{
                    
                    Map(position: $cameraPosition) {
                        UserAnnotation()
                        if !locationService.locations.isEmpty {
                            MapPolyline(coordinates: locationService.locations.map { $0.coordinate })
                                .stroke(.blue, lineWidth: 3)
                            
                        }
                    }
                    .padding(.top, 55)
                    .mapControls{
                        MapCompass()
                        MapUserLocationButton()
                        MapScaleView()
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
                                print("Showing route details overlay")
                                showRouteDetailsOverlay = true
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
                if showRouteDetailsOverlay {
                    // Use a transparent "hit zone" for detecting taps outside the card
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showRouteDetailsOverlay = false
                        }
                        .ignoresSafeArea()
                        .zIndex(90)
                    
                    RouteDetailsOverlay(isPresented: $showRouteDetailsOverlay) { name, description in
                        trackingManager.stopTracking(
                            userId: userId,
                            routeName: name,
                            routeDescription: description
                        )
                    }
                    .zIndex(100)
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
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
