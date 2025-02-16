import SwiftUI
import MapKit

struct PostView: View {
    @ObservedObject var viewModel: ExploreViewModel
    @State private var liked: Bool
    @State private var newComment = ""
    @State private var showCommentsSheet = false
    
    var post: Post

    init(post: Post, viewModel: ExploreViewModel) {
        self.post = post
        self.viewModel = viewModel
        self._liked = State(initialValue: false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Swipeable image carousel
            TabView {
                RoutePreviewMap(route: post.route)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                ForEach(post.photos, id: \.self) { photoUrl in
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
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .frame(height: 250)

            // Like & Comment Section
            HStack {
                Button(action: {
                    liked.toggle()
                    viewModel.likePost(postId: post.id)
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

            // View All Comments Button
            if post.comments.count > 2 {
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
                    viewModel.addComment(postId: post.id, userId: "currentUser", username: "You", text: newComment)
                    newComment = ""
                }) {
                    Text("Post")
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showCommentsSheet) {
            CommentsSheet(post: post, viewModel: viewModel, showCommentsSheet: $showCommentsSheet)
        }
    }
}

// MARK: - Comments Sheet View
struct CommentsSheet: View {
    var post: Post
    @ObservedObject var viewModel: ExploreViewModel
    @Binding var showCommentsSheet: Bool

    var body: some View {
        NavigationView {
            List {
                ForEach(post.comments) { comment in
                    VStack(alignment: .leading) {
                        Text(comment.username)
                            .fontWeight(.bold)
                        Text(comment.text)
                    }
                    .font(.caption)
                }
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

// MARK: - Route Map Preview (Locked)
struct RoutePreviewMap: View {
    var route: Route

    var body: some View {
        ZStack {
            Map {
                let coordinates = route.coordinates.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                if !coordinates.isEmpty {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.blue, lineWidth: 3)
                }
            }
            .disabled(true)
            .allowsHitTesting(false)
            
            Rectangle()
                .foregroundColor(.clear)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
