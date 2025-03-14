import SwiftUI
import MapKit
import Polyline

struct PostView: View {
    @ObservedObject var viewModel: ExploreViewModel
    @StateObject private var postViewModel = PostViewModel()
    @State private var liked: Bool
    @State private var newComment = ""
    @State private var showCommentsSheet = false
    @State private var showFullSpotifyList = false
    @EnvironmentObject var authManager: AuthenticationManager
    
    @ObservedObject var garageManager = GarageManager.shared
    @ObservedObject var firestoreManager = FirestoreManager.shared

    
    var post: Post

    init(post: Post, viewModel: ExploreViewModel) {
        self.post = post
        self.viewModel = viewModel
        self._liked = State(initialValue: false)
    }

    var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if let profileImage = postViewModel.profileImage {
                            Image(uiImage: profileImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                        }
                        Text(post.username)
                            .font(.headline)
                            .foregroundColor(.gray)
                        Spacer()
                        let equippedCar = post.car
                        if(post.car == ""){
                            
                        }else{
                            Image("\(equippedCar)2d")
                                .resizable()
                                .frame(width: 180, height: 90)
                                .padding(.trailing, 0)
                        }
                        
                    }
                        
                    // Username and post name aligned to the left
                    Text(post.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    HStack {
                        Text(String(format: "%.2f m", post.distance))
                        Spacer()
                        Text(formatDate(post.route.date))
                        Spacer()
                        Text(formatDuration(post.duration))
                    }
                    .font(.subheadline)
                    .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                ZStack(alignment: .bottomTrailing) {
                    TabView {
                        RoutePreviewMap(post: post)
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        ForEach(post.photos, id: \ .self) { photoUrl in
                            AsyncImage(url: URL(string: photoUrl)) { image in
                                image.resizable()
                                    .scaledToFit()
                                    .frame(height: 250)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } placeholder: {
                                Color.gray.opacity(0.3)
                                    .frame(height: 250)
                            }
                        }
                        if let spotifySongs = post.spotifyTracks, !spotifySongs.isEmpty {
                            SpotifyTracksPreview(tracks: spotifySongs, showFullList: $showFullSpotifyList)
                                .frame(height: 250)
                        }
                    }
                    .onAppear {
                        postViewModel.loadProfilePicture(userId: post.userid)
                    }
                    .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
                    .frame(height: 250)
                }
                
                // Like & Comment Section
                HStack {
                    Button(action: {
                        Task {
                            await viewModel.likePost(postId: post.id, userId: authManager.userId ?? "")
                            liked.toggle()
                        }
                    }) {
                        Image(systemName: liked ? "heart.fill" : "heart")
                            .foregroundColor(liked ? .red : .gray)
                    }
                    Text("\(post.likes) likes")
                    
                    Spacer()
                    
                    Button(action: {
                        showCommentsSheet = true
                    }) {
                        Image(systemName: "message")
                    }
                    Text("\(post.comments.count) comments")
                }
                .padding(.horizontal)
                
                if !post.description.isEmpty {
                    Text(post.description)
                        .font(.body)
                        .padding(.horizontal)
                        .padding(.top, 4)
                }
                
                // View All Comments Button
                if post.comments.count > 0 {
                    Button("View all comments") {
                        showCommentsSheet = true
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal)
                }
                
                // Add Comment Input
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
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .onAppear {
                viewModel.checkUserLikeStatus(
                    postId: post.id,
                    userId: authManager.userId ?? ""
                ) { isLiked in
                    liked = isLiked
                }
            }
            .sheet(isPresented: $showFullSpotifyList) {
                if let spotifySongs = post.spotifyTracks, !spotifySongs.isEmpty {
                    SpotifyTracksFullListView(tracks: spotifySongs)
                        .preferredColorScheme(.dark)
                }
            }
            .sheet(isPresented: $showCommentsSheet) {
                CommentsSheet(post: post, viewModel: viewModel, showCommentsSheet: $showCommentsSheet)
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }


// MARK: - Comments Sheet View
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
                
                // Add comment input field at the bottom
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
            /*
            .task {
                // Reload comments when sheet appears
                await viewModel.loadCommentsForPost(post: post)
            } */
        }
    }
}
// MARK: - Route Map Preview (Locked)
struct RoutePreviewMap: View {
    var post: Post
    
    var body: some View {
        ZStack {
            let polyline = Polyline(encodedPolyline: post.polyline)
            
            if let locations = polyline.locations, !locations.isEmpty {
                Map {
                    Marker("Start",
                           coordinate: locations.first!.coordinate)
                    .tint(.green)
                    
                    Marker("End",
                           coordinate: locations.last!.coordinate)
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
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            
        }
    }
}

class PostViewModel: ObservableObject {
    @Published var profileImage: UIImage?
    private var imageLoadTask: Task<Void, Never>?
    private let firestoreManager = FirestoreManager.shared
    
    func loadProfilePicture(userId: String) {
        // Cancel any existing task
        imageLoadTask?.cancel()
        
        // Create a new task to load the profile picture
        imageLoadTask = Task {
            do {
                // Use the abstracted method from FirestoreManager
                let image = try await firestoreManager.getUserProfileImage(userId: userId)
                
                // Update the UI on the main thread
                if !Task.isCancelled {
                    await MainActor.run {
                        self.profileImage = image
                    }
                }
            } catch {
                print("Error loading profile picture: \(error)")
            }
        }
    }
    
    deinit {
        imageLoadTask?.cancel()
    }
    
}
