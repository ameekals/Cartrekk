import Foundation

class ExploreViewModel: ObservableObject {
    @Published var posts: [Post] = []
    private let db = FirestoreManager()


    @MainActor
    func loadPublicPosts() async {
        let posts = await withCheckedContinuation { continuation in
            db.getPublicRoutes { routes in
                let sortedRoutes = (routes ?? []).sorted(by: { $0.createdAt > $1.createdAt })
                
                // Convert fb_Route to Post
                let posts = sortedRoutes.map { route in
                    Post(
                        id: route.docID,
                        route: Route(
                            id: UUID(),
                            date: route.createdAt,
                            coordinates: []
                        ),
                        photos: route.routeImages!,
                        likes: route.likes,
                        comments: [], // You might want to load comments separately
                        polyline: route.polyline
                    )
                }
                
                continuation.resume(returning: posts)
            }
        }
            
        self.posts = posts
        
        await withTaskGroup(of: Void.self) { group in
            for post in posts {
                group.addTask {
                    await self.loadCommentsForPost(post: post)
                }
            }
        }

    }
    
    @MainActor
    func loadCommentsForPost(post: Post) async {
        let comments = await withCheckedContinuation { continuation in
            db.getCommentsForRoute(routeId: post.id) { comments in
                continuation.resume(returning: comments ?? [])
            }
        }
        
        // Update the post with new comments
        if let index = self.posts.firstIndex(where: { $0.id == post.id }) {
            self.posts[index].comments = comments
        }
    }

    func likePost(postId: String) {
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].likes += 1
            objectWillChange.send()
        }
    }

    func addComment(postId: String, userId: String, username: String, text: String) {
        let newComment = Comment(id: UUID().uuidString, userId: userId, username: username, text: text, timestamp: Date())
        if let index = posts.firstIndex(where: { $0.id == postId }) {
            posts[index].comments.append(newComment)
            objectWillChange.send()
        }
    }
}
