import Foundation
import SwiftUI

class ExploreViewModel: ObservableObject {
    @Published var posts: [Post] = []
    private let db = FirestoreManager()
    @Published var profileImage: UIImage?
    private var imageLoadTask: Task<Void, Never>?

    @MainActor
    func loadFriendsPosts(userId: String) async {
        let posts = await withCheckedContinuation { continuation in
            db.getFriendsPosts(userId: userId) { routes in
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
                        comments: [],
                        polyline: route.polyline,
                        userid: route.userId,
                        username: route.userId,
                        name: route.name,
                        description: route.description,
                        distance: route.distance,
                        duration: route.duration,
                        spotifyTracks: route.spotifySongs ?? [],
                        car: route.equipedCar
                    )
                    
                }
                
                
                for (index, post) in posts.enumerated() {
                    self.db.fetchUsernameSync(userId: post.userid) { username in
                        if let username = username {
                            if self.posts.count > 0 {
                                self.posts[index].username = username
                            }
                        }
                    }
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

    @MainActor
    func addComment(postId: String, userId: String, username: String, text: String) async {
        await withCheckedContinuation { continuation in
            db.addCommentToRoute(routeId: postId, userId: userId, text: text) { error in
                if let error = error {
                    print("Error adding comment: \(error)")
                } else {
                    // Only update the UI if the database write was successful
                    if let index = self.posts.firstIndex(where: { $0.id == postId }) {
                        let newComment = Comment(
                            id: UUID().uuidString,  // The Firebase document ID would be better here
                            userId: userId,
                            username: username,
                            text: text,
                            timestamp: Date()
                        )
                        self.posts[index].comments.append(newComment)
                        self.objectWillChange.send()
                    }
                }
                continuation.resume()
            }
        }
    }
    
    @MainActor
    func updateLikesForPost(postId: String) {
        Task {
            await withCheckedContinuation { continuation in
                db.getLikeCount(routeId: postId) { likeCount in
                    if let index = self.posts.firstIndex(where: { $0.id == postId }) {
                        self.posts[index].likes = likeCount
                        self.objectWillChange.send()
                    }
                    continuation.resume()
                }
            }
        }
    }
        
    @MainActor
    func likePost(postId: String, userId: String) async {
        await withCheckedContinuation { continuation in
            db.handleLike(routeId: postId, userId: userId) { error in
                if let error = error {
                    print("Error handling like: \(error)")
                } else {
                    // Update like count after successful Firebase operation
                    self.updateLikesForPost(postId: postId)
                }
                continuation.resume()
            }
        }
    }
    
    func checkUserLikeStatus(postId: String, userId: String, completion: @escaping (Bool) -> Void) {
        db.getUserLikeStatus(routeId: postId, userId: userId, completion: completion)
    }


}
