import SwiftUI
import MapKit
import Polyline

// MARK: - Compact Post View (for Explore feed)
struct PostView: View {
    @ObservedObject var viewModel: ExploreViewModel
    @StateObject private var postViewModel = PostViewModel()
    @State private var showDetailView = false
    @EnvironmentObject var authManager: AuthenticationManager
    
    var post: Post

    init(post: Post, viewModel: ExploreViewModel) {
        self.post = post
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with profile info
            HStack {
                if let profileImage = postViewModel.profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundColor(.gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(formatDate(post.route.date))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Car image (smaller)
                if !post.car.isEmpty {
                    Image("\(post.car)2d")
                        .resizable()
                        .frame(width: 60, height: 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // Map (main content) - tappable
            Button(action: {
                showDetailView = true
            }) {
                ZStack(alignment: .bottomLeading) {
                    RoutePreviewMap(post: post)
                        .frame(height: 300)
                    
                    // Overlay with post name and basic info
                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        HStack {
                            Text(String(format: "%.2f m", post.distance))
                            Text("•")
                            Text(formatDuration(post.duration))
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
                }
            }
            .buttonStyle(PlainButtonStyle())
            
            // Quick stats bar
            HStack {
                Button(action: {
                    // Quick like action
                    Task {
                        await viewModel.likePost(postId: post.id, userId: authManager.userId ?? "")
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .foregroundColor(.secondary)
                        Text("\(post.likes)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showDetailView = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "message")
                            .foregroundColor(.secondary)
                        Text("\(post.comments.count)")
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let spotifyTracks = post.spotifyTracks, !spotifyTracks.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                        Text("\(spotifyTracks.count)")
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
        .onAppear {
            postViewModel.loadProfilePicture(userId: post.userid)
        }
        .fullScreenCover(isPresented: $showDetailView) {
            PostDetailView(post: post, viewModel: viewModel)
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

// MARK: - Full Detail View (Hinge-style)
struct PostDetailView: View {
    @ObservedObject var viewModel: ExploreViewModel
    @StateObject private var postViewModel = PostViewModel()
    @State private var liked: Bool = false
    @State private var newComment = ""
    @State private var showCommentsSheet = false
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    var post: Post

    init(post: Post, viewModel: ExploreViewModel) {
        self.post = post
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Large interactive map
                    RouteDetailMap(post: post)
                        .frame(height: 400)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Header section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                if let profileImage = postViewModel.profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 50)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundColor(.gray)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(post.username)
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    
                                    Text(formatDate(post.route.date))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if !post.car.isEmpty {
                                    Image("\(post.car)2d")
                                        .resizable()
                                        .frame(width: 120, height: 60)
                                }
                            }
                            
                            Text(post.name)
                                .font(.title)
                                .fontWeight(.bold)
                            
                            // Route stats
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("DISTANCE")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(String(format: "%.2f m", post.distance))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("DURATION")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(formatDuration(post.duration))
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Description
                        if !post.description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ABOUT THIS ROUTE")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text(post.description)
                                    .font(.body)
                                    .lineLimit(nil)
                            }
                            .padding(.horizontal, 20)
                        }
                        
                        // Photos section
                        if !post.photos.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("PHOTOS")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(post.photos, id: \.self) { photoUrl in
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
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                        }
                        
                        // Spotify tracks section
                        if let spotifyTracks = post.spotifyTracks, !spotifyTracks.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("SOUNDTRACK")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 20)
                                
                                LazyVStack(spacing: 8) {
                                    ForEach(spotifyTracks, id: \.id) { track in
                                        SpotifyTrackRow(track: track)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
                        
                        // Interaction section
                        VStack(spacing: 16) {
                            HStack {
                                Button(action: {
                                    Task {
                                        await viewModel.likePost(postId: post.id, userId: authManager.userId ?? "")
                                        liked.toggle()
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: liked ? "heart.fill" : "heart")
                                            .foregroundColor(liked ? .red : .primary)
                                        Text("\(post.likes) likes")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.vertical, 12)
                                    .padding(.horizontal, 20)
                                    .background(Color(.systemGray6))
                                    .clipShape(Capsule())
                                }
                                
                                Button(action: {
                                    showCommentsSheet = true
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "message")
                                        Text("\(post.comments.count) comments")
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
                            
                            // Add comment input
                            HStack {
                                TextField("Add a comment...", text: $newComment)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                
                                Button(action: {
                                    Task {
                                        await viewModel.addComment(postId: post.id, userId: authManager.userId ?? "", username: authManager.username ?? "", text: newComment)
                                        newComment = ""
                                    }
                                }) {
                                    Text("Post")
                                        .fontWeight(.bold)
                                        .foregroundColor(.blue)
                                }
                                .disabled(newComment.isEmpty)
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Recent comments preview
                        if !post.comments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("RECENT COMMENTS")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Spacer()
                                    
                                    Button("View All") {
                                        showCommentsSheet = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 20)
                                
                                VStack(spacing: 8) {
                                    ForEach(Array(post.comments.prefix(3))) { comment in
                                        CommentRow(comment: comment)
                                            .padding(.horizontal, 20)
                                    }
                                }
                            }
                        }
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
        .onAppear {
            postViewModel.loadProfilePicture(userId: post.userid)
            viewModel.checkUserLikeStatus(
                postId: post.id,
                userId: authManager.userId ?? ""
            ) { isLiked in
                liked = isLiked
            }
        }
        .sheet(isPresented: $showCommentsSheet) {
            CommentsSheet(post: post, viewModel: viewModel, showCommentsSheet: $showCommentsSheet)
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
}

// MARK: - Supporting Views

struct RouteDetailMap: View {
    var post: Post
    
    var body: some View {
        let polyline = Polyline(encodedPolyline: post.polyline)
        
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

struct SpotifyTrackRow: View {
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

struct CommentRow: View {
    let comment: Comment
    
    var body: some View {
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
}

// Keep your existing RoutePreviewMap and CommentsSheet as they are
struct RoutePreviewMap: View {
    var post: Post
    
    var body: some View {
        ZStack {
            let polyline = Polyline(encodedPolyline: post.polyline)
            
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
}

// Keep your existing CommentsSheet as is
struct CommentsSheet: View {
    var post: Post
    @ObservedObject var viewModel: ExploreViewModel
    @Binding var showCommentsSheet: Bool
    @State private var newComment: String = ""
    @EnvironmentObject var authManager: AuthenticationManager
    
    func handleAddComment() async {
        if !newComment.isEmpty {
            await viewModel.addComment(
                postId: post.id,
                userId: authManager.userId ?? "",
                username: authManager.username ?? "",
                text: newComment
            )
            newComment = ""
        }
    }
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(post.comments) { comment in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(comment.username)
                                .fontWeight(.bold)
                            Text(comment.text)
                            Text(comment.timestamp, style: .relative)
                                .foregroundColor(.gray)
                        }
                        .font(.caption)
                    }
                }
                
                HStack {
                    TextField("Add a comment...", text: $newComment)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button(action: {
                        Task {
                            await handleAddComment()
                        }
                    }) {
                        Text("Post")
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing)
                    .disabled(newComment.isEmpty)
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Comments")
            .toolbar {
                Button("Close") {
                    showCommentsSheet = false
                }
            }
        }
    }
}
