import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Polyline
import MapKit
import SafariServices

// MARK: - Past Routes View
struct PastRoutesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var garageManager = GarageManager.shared
    @StateObject private var viewModel = ProfileViewModel()
    
    var totalDistanceTraveled: Double {
        viewModel.routes.reduce(0) { $0 + $1.distance }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.routes.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "map")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            
                            Text("No past routes available.")
                                .font(.headline)
                                .foregroundColor(.gray)
                            
                            Text("Start tracking routes to see them here!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 100)
                    } else {
                        ForEach(viewModel.routes, id: \.docID) { route in
                            PastRouteCard(route: route, onDelete: {
                                // Remove the route locally from viewModel.routes
                                if let index = viewModel.routes.firstIndex(where: { $0.docID == route.docID }) {
                                    viewModel.routes.remove(at: index)
                                }
                            })
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("Past Routes")
            .navigationBarTitleDisplayMode(.large)
            .background(Color(.systemBackground))
        }
        .onAppear {
            if let userId = authManager.userId {
                Task {
                    await viewModel.loadRoutes(userId: userId)
                    garageManager.fetchTotalMiles(userId: userId)
                }
            }
        }
    }
}

// MARK: - Past Route Card (Hinge-style)
struct PastRouteCard: View {
    let route: FirestoreManager.fb_Route
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isCurrentlyPublic: Bool
    @State private var showDetailView = false
    @State private var showFullSpotifyList = false
    @State private var showDeleteConfirmation = false
    @State private var showPostConfirmation = false
    
    var onDelete: () -> Void
    
    init(route: FirestoreManager.fb_Route, onDelete: @escaping () -> Void) {
        self.route = route
        self.onDelete = onDelete
        _isCurrentlyPublic = State(initialValue: route.isPublic)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with route info and delete button
            HStack {
                VStack(alignment: .leading, spacing: 2) {
//                    Text(route.name.isEmpty ? "Untitled Route" : route.name)
//                        .font(.subheadline)
//                        .fontWeight(.medium)
//                        .foregroundColor(.primary)
                    
                    Text(formatDate(route.createdAt))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Map (main content) - tappable
            Button(action: {
                showDetailView = true
            }) {
                ZStack(alignment: .bottomLeading) {
                    PastRoutePreviewMap(route: route)
                        .frame(height: 300)
                    
                    // Overlay with route stats
                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name.isEmpty ? "Route" : route.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text(String(format: "%.2f m", route.distance))
                            Text("•")
                            Text(formatDuration(route.duration))
                        }
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(16)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.7)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Invisible overlay to make entire area tappable
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Stats and actions bar
            HStack {
                // Likes
                HStack(spacing: 4) {
                    Image(systemName: "heart")
                        .foregroundColor(.secondary)
                    Text("\(route.likes)")
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Public/Private status
                Button(action: {
                    showPostConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: isCurrentlyPublic ? "globe" : "globe.slash")
                            .foregroundColor(isCurrentlyPublic ? .blue : .secondary)
                        Text(isCurrentlyPublic ? "Public" : "Private")
                            .foregroundColor(isCurrentlyPublic ? .blue : .secondary)
                    }
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                // Photos indicator
                if let routeImages = route.routeImages, !routeImages.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                        Text("\(routeImages.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                // Spotify indicator
                if let spotifySongs = route.spotifySongs, !spotifySongs.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                        Text("\(spotifySongs.count)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .font(.caption)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .fullScreenCover(isPresented: $showDetailView) {
            PastRouteDetailView(route: route)
        }
        .sheet(isPresented: $showFullSpotifyList) {
            if let spotifySongs = route.spotifySongs, !spotifySongs.isEmpty {
                SpotifyTracksFullListView(tracks: spotifySongs)
                    .preferredColorScheme(.dark)
            }
        }
        .confirmationDialog(
            "Delete Route",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    if await viewModel.deleteRoute(routeId: route.docID) {
                        onDelete()
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
        .confirmationDialog(
            isCurrentlyPublic ? "Make Private" : "Make Public",
            isPresented: $showPostConfirmation
        ) {
            Button(isCurrentlyPublic ? "Make Private" : "Make Public") {
                isCurrentlyPublic.toggle()
                Task {
                    await viewModel.togglePublicStatus(routeId: route.docID)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

//MARK: PastRouteDetailView
struct PastRouteDetailView: View {
    let route: FirestoreManager.fb_Route
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showCommentsSheet = false
    @State private var routeComments: [Comment] = []
    @State private var isCurrentlyPublic: Bool
    @State private var showPostConfirmation = false
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage? // Changed from capturedImage to selectedImage
    @State private var showImageSourcePicker = false
    @State private var routeImages: [String] // Local copy that we can update
    
    init(route: FirestoreManager.fb_Route) {
        self.route = route
        _isCurrentlyPublic = State(initialValue: route.isPublic)
        _routeImages = State(initialValue: route.routeImages ?? [])
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Large interactive map
                    PastRouteDetailMap(route: route)
                        .frame(height: 400)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Header section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                // User info placeholder (you could add profile image here)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Your Route")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text(formatDate(route.createdAt))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            Text(route.name.isEmpty ? "Untitled Route" : route.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            // Route stats
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("DISTANCE")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f m", route.distance))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("DURATION")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDuration(route.duration))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Description
                        if !route.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ABOUT THIS ROUTE")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(route.description)
                                    .font(.body)
                                    .lineLimit(nil)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Photos section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("PHOTOS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Spacer()
                                
                                Button(action: {
                                    showImageSourcePicker = true
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "plus")
                                            .font(.caption)
                                        Text("Add Photo")
                                            .font(.caption)
                                    }
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.blue.opacity(0.1))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            if !routeImages.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(routeImages, id: \.self) { photoUrl in
                                            ZStack(alignment: .topTrailing) {
                                                AsyncImage(url: URL(string: photoUrl)) { image in
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 200, height: 150)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                } placeholder: {
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 200, height: 150)
                                                }
                                                
                                                // Delete button for each image
                                                Button(action: {
                                                    deleteImage(imageUrl: photoUrl)
                                                }) {
                                                    Image(systemName: "xmark.circle.fill")
                                                        .foregroundColor(.red)
                                                        .background(Color.white)
                                                        .clipShape(Circle())
                                                        .font(.title3)
                                                }
                                                .padding(8)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundColor(.gray)
                                    
                                    Text("No photos yet")
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                    
                                    Button(action: {
                                        showImageSourcePicker = true
                                    }) {
                                        Text("Add your first photo")
                                            .foregroundColor(.blue)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(Color.blue.opacity(0.1))
                                            .clipShape(Capsule())
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 20)
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Spotify tracks section
                        if let spotifySongs = route.spotifySongs, !spotifySongs.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SOUNDTRACK")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(spotifySongs, id: \.id) { track in
                                        PastRouteSpotifyTrackRow(track: track)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        
                        // Interaction section
                        VStack(spacing: 16) {
                            HStack {
                                // Likes display (read-only for past routes)
                                HStack(spacing: 8) {
                                    Image(systemName: "heart")
                                        .foregroundColor(.red)
                                    Text("\(route.likes) likes")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 20)
                                .background(Color(.systemGray6))
                                .clipShape(Capsule())
                                
                                Button(action: {
                                    Task {
                                        routeComments = await viewModel.loadCommentsForRoute(routeId: route.docID)
                                        showCommentsSheet = true
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "message")
                                        Text("View comments")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                                }
                                
                                Spacer()
                            }
                            
                            // Public/Private toggle section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("VISIBILITY")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button(action: {
                                    showPostConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: isCurrentlyPublic ? "globe" : "globe.slash")
                                            .foregroundColor(isCurrentlyPublic ? .blue : .gray)
                                            .font(.title2)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(isCurrentlyPublic ? "Public Route" : "Private Route")
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                            
                                            Text(isCurrentlyPublic ?
                                                "Visible to everyone on Explore" :
                                                "Only visible to you")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        Spacer()
                                        
                                        Text(isCurrentlyPublic ? "Make Private" : "Make Public")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(isCurrentlyPublic ? .red : .blue)
                                    }
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showCommentsSheet) {
            PastRouteCommentsSheet(routeComments: routeComments)
        }
        .sheet(isPresented: $showCamera) {
            CameraView(image: $selectedImage)
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .actionSheet(isPresented: $showImageSourcePicker) {
            ActionSheet(
                title: Text("Add Photo"),
                buttons: [
                    .default(Text("Camera")) {
                        showCamera = true
                    },
                    .default(Text("Photo Library")) {
                        showImagePicker = true
                    },
                    .cancel()
                ]
            )
        }
        .onChange(of: selectedImage) { newImage in
            if let image = newImage {
                uploadNewImage(image)
                selectedImage = nil // Reset after processing
            }
        }
        .confirmationDialog(
            isCurrentlyPublic ? "Make Private" : "Make Public",
            isPresented: $showPostConfirmation
        ) {
            Button(isCurrentlyPublic ? "Make Private" : "Make Public") {
                isCurrentlyPublic.toggle()
                Task {
                    await viewModel.togglePublicStatus(routeId: route.docID)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isCurrentlyPublic ?
                "This will hide your route from the Explore feed. You can make it public again later." :
                "This will show your route on the Explore feed for others to see.")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    // MARK: - Image Management Functions
    
    private func uploadNewImage(_ image: UIImage) {
        Task {
            do {
                // Upload image to S3 or your storage service
                let imageURL = try await uploadImageToS3(
                    image: image,
                    bucketName: "cartrekk-images"
                )
                
                // Update local state immediately for responsive UI
                DispatchQueue.main.async {
                    routeImages.append(imageURL)
                }
                
                // Update the route in the database
                await viewModel.addImageToRoute(routeId: route.docID, imageUrl: imageURL)
                
                print("Image uploaded successfully: \(imageURL)")
            } catch {
                print("Error uploading image: \(error)")
                // You might want to show an alert to the user here
            }
        }
    }
    
    private func deleteImage(imageUrl: String) {
        Task {
            // Update local state immediately for responsive UI
            DispatchQueue.main.async {
                routeImages.removeAll { $0 == imageUrl }
            }
            
            // Update the route in the database
            await viewModel.removeImageFromRoute(routeId: route.docID, imageUrl: imageUrl)
            
            // Optionally delete the image from storage
            // await deleteImageFromS3(imageUrl: imageUrl)
            
            print("Image removed from route: \(imageUrl)")
        }
    }
}

// MARK: - Supporting Views for Past Routes

struct PastRoutePreviewMap: View {
    let route: FirestoreManager.fb_Route
    
    var body: some View {
        let polyline = Polyline(encodedPolyline: route.polyline)
        
        if let locations = polyline.locations, !locations.isEmpty {
            Map {
                Marker("Start", coordinate: locations.first!.coordinate)
                    .tint(.green)
                
                Marker("End", coordinate: locations.last!.coordinate)
                    .tint(.red)
                
                MapPolyline(coordinates: locations.map { $0.coordinate })
                    .stroke(
                        Color.blue.opacity(0.8),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .butt,
                            lineJoin: .round,
                            miterLimit: 10
                        )
                    )
            }
            .disabled(true)
            .allowsHitTesting(false)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct PastRouteDetailMap: View {
    let route: FirestoreManager.fb_Route
    
    var body: some View {
        let polyline = Polyline(encodedPolyline: route.polyline)
        
        if let locations = polyline.locations, !locations.isEmpty {
            Map {
                Marker("Start", coordinate: locations.first!.coordinate)
                    .tint(.green)
                
                Marker("End", coordinate: locations.last!.coordinate)
                    .tint(.red)
                
                MapPolyline(coordinates: locations.map { $0.coordinate })
                    .stroke(
                        Color.blue.opacity(0.8),
                        style: StrokeStyle(
                            lineWidth: 4,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
            }
            .mapStyle(.standard)
        }
    }
}

struct PastRouteSpotifyTrackRow: View {
    let track: SpotifyTrack
    
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: URL(string: track.albumImageUrl ?? "")) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .frame(width: 50, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(track.artists)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "music.note")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

struct PastRouteCommentsSheet: View {
    let routeComments: [Comment]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                if !routeComments.isEmpty {
                    ForEach(routeComments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(comment.username)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text(comment.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(comment.text)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                } else {
                    Text("No comments yet")
                        .foregroundColor(.gray)
                        .italic()
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

//// MARK: - Image Picker View
//struct ImagePicker: UIViewControllerRepresentable {
//    @Binding var image: UIImage?
//    @Environment(\.dismiss) private var dismiss
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator(self)
//    }
//
//    func makeUIViewController(context: Context) -> UIImagePickerController {
//        let picker = UIImagePickerController()
//        picker.sourceType = .photoLibrary
//        picker.delegate = context.coordinator
//        picker.allowsEditing = true
//        return picker
//    }
//
//    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
//
//    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
//        let parent: ImagePicker
//
//        init(_ parent: ImagePicker) {
//            self.parent = parent
//        }
//
//        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
//            if let selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
//                parent.image = selectedImage
//            }
//            parent.dismiss()
//        }
//
//        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
//            parent.dismiss()
//        }
//    }
//}

// MARK: - Camera View
struct P_CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: P_CameraView

        init(_ parent: P_CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let selectedImage = info[.editedImage] as? UIImage ?? info[.originalImage] as? UIImage {
                parent.image = selectedImage
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
