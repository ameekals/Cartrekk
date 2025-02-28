//
//  FirebaseManager.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 2/10/25.
//
import Firebase
import FirebaseFirestore
import FirebaseCore


class FirestoreManager{
    static let shared = FirestoreManager()
    let db = Firestore.firestore()
    
    
    
    func getRoutesForUser(userId: String, completion: @escaping ([fb_Route]?) -> Void) {
        let routesRef = db.collection("routes")
        
        routesRef.whereField("userid", isEqualTo: userId).getDocuments(source: .default) { (snapshot, error) in
            if let error = error {
                print("Error fetching routes: \(error)")
                completion(nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                completion(nil)
                return
            }
            
            // Parse documents into Route models
            let routes: [fb_Route] = documents.compactMap { document in
                let data = document.data()
                return fb_Route(
                    docID: document.documentID,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    distance: data["distance"] as? Double ?? 0.0,
                    duration: data["duration"] as? Double ?? 0.0,
                    likes: data["likes"] as? Int ?? 0,
                    polyline: data["polyline"] as? String ?? "",
                    isPublic: data["public"] as? Bool ?? false,
                    routeImages: data["routeImages"] as? [String] ?? [],
                    userId: data["userid"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    name: data["name"] as? String ?? ""
                )
            }
            
            completion(routes)
        }
    }
    
    func incrementUserTotalDistance(userId: String, additionalDistance: Double, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "total_distance": FieldValue.increment(additionalDistance)
        ]) { error in
            if let error = error {
                print("Error updating total distance: \(error)")
                
                // Check if the field doesn't exist yet and needs to be created
                if (error as NSError).domain == FirestoreErrorDomain &&
                   (error as NSError).code == FirestoreErrorCode.notFound.rawValue {
                    
                    // Field doesn't exist, so set it instead of incrementing
                    userRef.setData([
                        "total_distance": additionalDistance
                    ], merge: true) { error in
                        completion(error)
                    }
                } else {
                    completion(error)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    func incrementUserDistanceUsed(userId: String, distanceUsed: Double, completion: @escaping (Error?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.updateData([
            "distance_used": FieldValue.increment(distanceUsed)
        ]) { error in
            if let error = error {
                print("Error updating distance used: \(error)")
                
                // Check if the field doesn't exist yet and needs to be created
                if (error as NSError).domain == FirestoreErrorDomain &&
                   (error as NSError).code == FirestoreErrorCode.notFound.rawValue {
                    
                    // Field doesn't exist, so set it instead of incrementing
                    userRef.setData([
                        "distance_used": distanceUsed
                    ], merge: true) { error in
                        completion(error)
                    }
                } else {
                    completion(error)
                }
            } else {
                completion(nil)
            }
        }
    }
    
    func fetchTotalDistanceForUser(userId: String, completion: @escaping (Double?) -> Void) {
        let userRef = db.collection("users").document(userId) // Reference to the user document

        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching total distance: \(error)")
                completion(nil)
                return
            }

            guard let document = document, document.exists else {
                print("User document not found for userId: \(userId)")
                completion(nil)
                return
            }

            // Extract total_distance from the user's document
            let totalDistance = document.data()?["total_distance"] as? Double ?? 0.0
            completion(totalDistance)
        }
    }
    
    func fetchUsableDistanceForUser(userId: String, completion: @escaping (Double?) -> Void) {
        let userRef = db.collection("users").document(userId) // Reference to the user document

        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching total distance: \(error)")
                completion(nil)
                return
            }

            guard let document = document, document.exists else {
                print("User document not found for userId: \(userId)")
                completion(nil)
                return
            }

            // Extract total_distance from the user's document
            let usableDistance = document.data()?["distance_used"] as? Double ?? 0.0
            completion(usableDistance)
        }
    }
    
    // 🔹 Function to save route details
    func saveRouteDetails(routeId: String, distance: Double, duration: Double, likes: Int, polyline: String, isPublic: Bool, routeImages: [String]?, userId: String, routeName: String, routeDescription: String, completion: @escaping () -> Void) {
        let routeRef = db.collection("routes").document(routeId)

        let data: [String: Any] = [
            "createdAt": Timestamp(date: Date()),
            "distance": distance,
            "duration": duration,
            "likes": likes,
            "polyline": polyline,
            "public": isPublic,
            "routeImages": routeImages as Any,
            "userid": userId,
            "name": routeName,
            "description": routeDescription
        ]

        routeRef.setData(data) { error in
            if let error = error {
                print("Error saving route: \(error)")
            } else {
                print("Route successfully saved!")
            }
            completion()
        }
    }
    
    func updateRouteImages(routeId: String, newImageUrl: String, completion: @escaping (Bool) -> Void) {
        let routeRef = db.collection("routes").document(routeId)
        
        // First get the current document to access existing images
        routeRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // Get current images array or create a new one if it doesn't exist
                var currentImages = document.data()?["routeImages"] as? [String] ?? []
                
                // Add the new image URL to the array
                if(newImageUrl == "null"){
                    print("image not found")
                }else{
                    currentImages.append(newImageUrl)
                }
                
                
                // Update only the routeImages field
                routeRef.updateData([
                    "routeImages": currentImages
                ]) { error in
                    if let error = error {
                        print("Error updating route images: \(error)")
                        completion(false)
                    } else {
                        print("Route images successfully updated!")
                        completion(true)
                    }
                }
            } else {
                print("Document does not exist or error: \(error?.localizedDescription ?? "unknown error")")
                completion(false)
            }
        }
    }
    
    func deleteRoute(routeId: String, completion: @escaping (Bool) -> Void) {
        let routeRef = db.collection("routes").document(routeId)
        
        routeRef.delete { error in
            if let error = error {
                print("Error deleting route: \(error)")
                completion(false)
            } else {
                print("Route successfully deleted!")
                completion(true)
            }
        }
    }
    
    func getPublicRoutes(completion: @escaping ([fb_Route]?) -> Void) {
        let routesRef = db.collection("routes")
        
        routesRef
            .whereField("public", isEqualTo: true)
            .order(by: "createdAt", descending: true)  // Get newest first
            .limit(to: 15)  // Only get 15 documents
            .getDocuments(source: .default) { (snapshot, error) in
            if let error = error {
                print("Error fetching public routes: \(error)")
                completion(nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No public routes found")
                completion(nil)
                return
            }
            
            // Parse documents into Route models
            let routes: [fb_Route] = documents.compactMap { document in
                let data = document.data()
                return fb_Route(
                    docID: document.documentID,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    distance: data["distance"] as? Double ?? 0.0,
                    duration: data["duration"] as? Double ?? 0.0,
                    likes: data["likes"] as? Int ?? 0,
                    polyline: data["polyline"] as? String ?? "",
                    isPublic: data["public"] as? Bool ?? false,
                    routeImages: data["routeImages"] as? [String] ?? [],
                    userId: data["userid"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    name: data["name"] as? String ?? ""
                )
            }
            
            completion(routes)
        }
    }
    
    func getCommentsForRoute(routeId: String, completion: @escaping ([Comment]?) -> Void) {
        let commentsRef = db.collection("routes").document(routeId).collection("comments")
        
        commentsRef.order(by: "createdAt", descending: true).getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching comments: \(error)")
                completion(nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No comments found for route: \(routeId)")
                completion(nil)
                return
            }
            
            let dispatchGroup = DispatchGroup()
            var comments: [Comment] = []
            
            for document in documents {
                let data = document.data()
                let userId = data["userid"] as? String ?? ""
                

                dispatchGroup.enter()
                self.fetchUsernameSync(userId: userId) { username in
                    let comment = Comment(
                        id: document.documentID,
                        userId: userId,
                        username: username ?? userId, // Fall back to userId if no username found
                        text: data["text"] as? String ?? "",
                        timestamp: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    )
                    comments.append(comment)
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                let sortedComments = comments.sorted { $0.timestamp > $1.timestamp }
                completion(sortedComments)
            }
        }
    }
    
    func addCommentToRoute(routeId: String, userId: String, text: String, completion: @escaping (Error?) -> Void) {
        let commentsRef = db.collection("routes").document(routeId).collection("comments")
        
        let commentData: [String: Any] = [
            "userid": userId,
            "text": text,
            "createdAt": Timestamp(date: Date())
        ]
        
        commentsRef.addDocument(data: commentData) { error in
            if let error = error {
                print("Error adding comment: \(error)")
                completion(error)
            } else {
                completion(nil)
            }
        }
    }

    func handleLike(routeId: String, userId: String, completion: @escaping (Error?) -> Void) {
        let likeRef = db.collection("routes").document(routeId).collection("likes").document(userId)
        let routeRef = db.collection("routes").document(routeId)

        // First check if the user has already liked the post
        likeRef.getDocument { (document, error) in
            if let error = error {
                completion(error)
                return
            }
            
            if let document = document, document.exists {
                // User already liked the post, so unlike it
                likeRef.delete { error in
                    if let error = error {
                        completion(error)
                        return
                    }
                    
                    // Only after successful deletion, update the count
                    routeRef.updateData(["likes": FieldValue.increment(Int64(-1))]) { error in
                        completion(error)  // Call completion once at the end
                    }
                }
            } else {
                // User hasn't liked the post, so add the like
                let likeData: [String: Any] = [
                    "timestamp": Timestamp(date: Date())
                ]
                likeRef.setData(likeData) { error in
                    if let error = error {
                        completion(error)
                        return
                    }
                    
                    // Only after successful addition, update the count
                    routeRef.updateData(["likes": FieldValue.increment(Int64(1))]) { error in
                        completion(error)  // Call completion once at the end
                    }
                }
            }
        }
    }

    func getUserLikeStatus(routeId: String, userId: String, completion: @escaping (Bool) -> Void) {
        let likeRef = db.collection("routes").document(routeId).collection("likes").document(userId)
        
        likeRef.getDocument { (document, error) in
            if let error = error {
                print("Error checking like status: \(error)")
                completion(false)
                return
            }
            
            completion(document?.exists ?? false)
        }
    }

    func getLikeCount(routeId: String, completion: @escaping (Int) -> Void) {
        let routeRef = db.collection("routes").document(routeId)
        
        routeRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching like count: \(error)")
                completion(0)
                return
            }
            
            if let document = document, document.exists {
                let likes = document.data()?["likes"] as? Int ?? 0
                completion(likes)
            } else {
                completion(0)
            }
        }
    }
    
    func fetchUsernameSync(userId: String, completion: @escaping (String?) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { (document, error) in
            if let document = document, document.exists {
                let username = document.data()?["username"] as? String
                completion(username)
            } else {
                completion(nil)
            }
        }
    }

    func fetchUsername(userId: String) async -> String? {
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            if document.exists {
                return document.data()?["username"] as? String
            }
            return nil
        } catch {
            print("Error fetching username: \(error)")
            return nil
        }
    }
    
    struct fb_Route {
        let docID: String
        let createdAt: Date
        let distance: Double
        let duration: Double
        let likes: Int
        let polyline: String
        let isPublic: Bool
        let routeImages: [String]?
        let userId: String
        let description: String
        let name: String
    }
    
    func searchUsers(query: String, currentUserId: String, completion: @escaping ([User]) -> Void) {
        guard !query.isEmpty else {
            completion([])
            return
        }
        
        db.collection("usernames")
            .whereField(FieldPath.documentID(), isGreaterThanOrEqualTo: query)
            .whereField(FieldPath.documentID(), isLessThanOrEqualTo: query + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments { (snapshot, error) in
                if let error = error {
                    print("Error searching for users: \(error.localizedDescription)")
                    completion([])
                    return
                }
                
                var users: [User] = []
                
                for document in snapshot?.documents ?? [] {
                    let username = document.documentID
                    let userData = document.data()
                    if let userId = userData["userid"] as? String,
                       userId != currentUserId {  // Don't show current user
                        users.append(User(id: userId, username: username))
                    }
                }
                
                completion(users)
            }
    }
        
    // Send friend request
    func sendFriendRequest(from senderId: String, to username: String, completion: @escaping (Bool, String?) -> Void) {
        // First get the user ID from the username
        db.collection("usernames").document(username).getDocument { [weak self] (snapshot, error) in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, "Error checking username: \(error.localizedDescription)")
                return
            }
            
            guard let snapshot = snapshot, snapshot.exists else {
                completion(false, "User not found")
                return
            }
            
            let data = snapshot.data() ?? [:]
            guard let targetUserId = data["userid"] as? String else {
                completion(false, "User not found")
                return
            }
            
            // Don't allow sending request to yourself
            if targetUserId == senderId {
                completion(false, "You cannot send a friend request to yourself")
                return
            }
            
            // Now update the target user's pending_friends array
            let userRef = self.db.collection("users").document(targetUserId)
            userRef.updateData([
                "pending_friends": FieldValue.arrayUnion([senderId])
            ]) { error in
                if let error = error {
                    completion(false, "Error sending friend request: \(error.localizedDescription)")
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    // Accept friend request
    func acceptFriendRequest(currentUserId: String, senderId: String, completion: @escaping (Bool, String?) -> Void) {
        let batch = db.batch()
        
        // Add sender to current user's friends list
        let currentUserRef = db.collection("users").document(currentUserId)
        batch.updateData([
            "friends": FieldValue.arrayUnion([senderId]),
            "pending_friends": FieldValue.arrayRemove([senderId])
        ], forDocument: currentUserRef)
        
        // Add current user to sender's friends list
        let senderRef = db.collection("users").document(senderId)
        batch.updateData([
            "friends": FieldValue.arrayUnion([currentUserId])
        ], forDocument: senderRef)
        
        // Commit the batch
        batch.commit { error in
            if let error = error {
                completion(false, "Error accepting friend request: \(error.localizedDescription)")
            } else {
                completion(true, nil)
            }
        }
    }
    
    // Decline friend request
    func declineFriendRequest(currentUserId: String, senderId: String, completion: @escaping (Bool, String?) -> Void) {
        let userRef = db.collection("users").document(currentUserId)
        userRef.updateData([
            "pending_friends": FieldValue.arrayRemove([senderId])
        ]) { error in
            if let error = error {
                completion(false, "Error declining friend request: \(error.localizedDescription)")
            } else {
                completion(true, nil)
            }
        }
    }
    
    // Load friends list
    func loadFriends(userId: String, completion: @escaping ([Friend]) -> Void) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading friends: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let snapshot = snapshot else {
                completion([])
                return
            }
            let data = snapshot.data() ?? [:]
            guard let friendIds = data["friends"] as? [String] else {
                completion([])
                return
            }
            
            
            if friendIds.isEmpty {
                completion([])
                return
            }
            
            // Fetch user details for each friend ID
            var friends: [Friend] = []
            let dispatchGroup = DispatchGroup()
            
            for friendId in friendIds {
                dispatchGroup.enter()
                self.db.collection("users").document(friendId).getDocument { friendSnapshot, error in
                    defer { dispatchGroup.leave() }
                    
                    if let friendData = friendSnapshot?.data(),
                       let username = friendData["username"] as? String {
                        friends.append(Friend(id: friendId, username: username))
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(friends)
            }
        }
    }
    
    // Load pending friend requests
    func loadPendingRequests(userId: String, completion: @escaping ([FriendRequest]) -> Void) {
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error loading requests: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let snapshot = snapshot else {
                completion([])
                return
            }
            let data = snapshot.data() ?? [:]
            guard let pendingIds = data["pending_friends"] as? [String] else {
                completion([])
                return
            }
            
            if pendingIds.isEmpty {
                completion([])
                return
            }
            
            // Fetch user details for each pending friend ID
            var requests: [FriendRequest] = []
            let dispatchGroup = DispatchGroup()
            
            for senderId in pendingIds {
                dispatchGroup.enter()
                self.db.collection("users").document(senderId).getDocument { friendSnapshot, error in
                    defer { dispatchGroup.leave() }
                    
                    if let friendData = friendSnapshot?.data(),
                       let username = friendData["username"] as? String {
                        requests.append(FriendRequest(id: UUID().uuidString, username: username, senderId: senderId))
                    }
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                completion(requests)
            }
        }
    }


}


