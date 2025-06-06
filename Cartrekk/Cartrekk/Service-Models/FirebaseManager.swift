//
//  FirebaseManager.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 2/10/25.
//
import Firebase
import FirebaseFirestore
import FirebaseCore

class FirestoreManager: ObservableObject{
    static let shared = FirestoreManager()
    let db = Firestore.firestore()
    
    // MARK: - Cognito Integration Functions
    
    func getCognitoIdentityIdForUser(userId: String) async throws -> String? {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data() else {
            return nil
        }
        
        return data["cognitoIdentityId"] as? String
    }
    
    func saveCognitoIdentityId(userId: String, cognitoId: String) async throws {
        try await db.collection("users").document(userId).updateData([
            "cognitoIdentityId": cognitoId,
            "cognitoCreatedAt": FieldValue.serverTimestamp()
        ])
    }
    
    // MARK: - Enhanced Image Functions
    
    func getProfilePictureURL(userId: String) async throws -> String? {
        let document = try await db.collection("users").document(userId).getDocument()
        
        guard let data = document.data(),
              let profileURL = data["profilePictureURL"] as? String,
              !profileURL.isEmpty else {
            return nil
        }
        
        return profileURL
    }

    func getUserProfileImage(userId: String) async throws -> UIImage? {
        guard let profileURL = try await getProfilePictureURL(userId: userId) else {
            return nil
        }
        
        // Use the new AWSService method
        return try await AWSService.shared.getImageFromS3(imageURL: profileURL)
    }
    
    func updateUserProfilePicture(userId: String, profileImage: UIImage) async throws -> Bool {
        do {
            // Upload image using new Cognito-integrated method
            let profilePictureURL = try await AWSService.shared.uploadImageForFirebaseUser(
                image: profileImage,
                firebaseUserId: userId
            )
            
            // Update Firebase with the new URL
            try await db.collection("users").document(userId).updateData([
                "profilePictureURL": profilePictureURL
            ])
            
            print("Profile picture successfully updated!")
            return true
        } catch {
            print("Error updating profile picture: \(error)")
            return false
        }
    }
    
    func updateUserProfilePicture(userId: String, profilePictureURL: String, completion: @escaping (Bool) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        // Update the profilePictureURL field
        userRef.updateData([
            "profilePictureURL": profilePictureURL
        ]) { error in
            if let error = error {
                print("Error updating profile picture: \(error)")
                completion(false)
            } else {
                print("Profile picture successfully updated!")
                completion(true)
            }
        }
    }
    
    // MARK: - Route Image Functions
    
    func updateRouteImages(routeId: String, newImage: UIImage, completion: @escaping (Bool) -> Void) {
        // Upload image using Cognito-integrated method
        Task {
            do {
                let imageURL = try await AWSService.shared.uploadImageToS3(image: newImage)
                
                // Update route with new image URL
                await MainActor.run {
                    self.updateRouteImages(routeId: routeId, newImageUrl: imageURL) { success in
                        completion(success)
                    }
                }
            } catch {
                print("Error uploading route image: \(error)")
                await MainActor.run {
                    completion(false)
                }
            }
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
    
    // MARK: - User Management Functions
    
    func createUserDocument(userId: String, userData: [String: Any]) async throws {
        var userDataWithCognito = userData
        
        // Initialize Cognito fields
        userDataWithCognito["cognitoIdentityId"] = nil
        userDataWithCognito["cognitoCreatedAt"] = nil
        
        try await db.collection("users").document(userId).setData(userDataWithCognito)
    }
    
    func ensureUserHasCognitoId(userId: String) async throws -> String {
        // Check if user already has Cognito ID
        if let existingCognitoId = try await getCognitoIdentityIdForUser(userId: userId) {
            return existingCognitoId
        }
        
        // Generate new Cognito ID using AWSService
        let cognitoId = try await AWSService.shared.getCognitoIdentityForUser(firebaseUserId: userId)
        return cognitoId
    }
    
    // MARK: - All your existing functions remain the same...
    
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
                
                // Parse Spotify songs
                var spotifySongs: [SpotifyTrack]? = nil
                if let spotifySongsData = data["spotifySongs"] as? [[String: Any]] {
                    var songs: [SpotifyTrack] = []
                    for songData in spotifySongsData {
                        if let id = songData["id"] as? String,
                           let name = songData["name"] as? String,
                           let artists = songData["artists"] as? String,
                           let albumName = songData["albumName"] as? String,
                           let playedAt = songData["playedAt"] as? String {
                            
                            let albumImageUrl = songData["albumImageUrl"] as? String
                            
                            let track = SpotifyTrack(
                                id: id,
                                name: name,
                                artists: artists,
                                albumName: albumName,
                                albumImageUrl: albumImageUrl,
                                playedAt: playedAt
                            )
                            songs.append(track)
                        }
                    }
                    if !songs.isEmpty {
                        spotifySongs = songs
                    }
                }
                
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
                    name: data["name"] as? String ?? "",
                    spotifySongs: spotifySongs,
                    equipedCar: data["equippedCar"] as? String ?? ""
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
        let userRef = db.collection("users").document(userId)

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

            let totalDistance = document.data()?["total_distance"] as? Double ?? 0.0
            completion(totalDistance)
        }
    }
    
    func fetchUsableDistanceForUser(userId: String, completion: @escaping (Double?) -> Void) {
        let userRef = db.collection("users").document(userId)

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

            let usableDistance = document.data()?["distance_used"] as? Double ?? 0.0
            completion(usableDistance)
        }
    }
    
    // MARK: - Continue with all your existing functions...
    // (I'm including the key ones and you can keep the rest as they are)
    
    func addCarToInventory(userId: String, carName: String, completion: @escaping (Bool, String) -> Void) {
        let userRef = db.collection("users").document(userId)

        userRef.updateData([
            "inventory": FieldValue.arrayUnion([carName])
        ]) { error in
            if let error = error {
                completion(false, "Error adding car: \(error.localizedDescription)")
            } else {
                completion(true, "Successfully added \(carName) to inventory!")
            }
        }
    }
    
    func addOrUpdateCarInInventory(userId: String, carName: String, newCount: Int, completion: @escaping (Bool, String) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        // First get the current inventory
        userRef.getDocument { (document, error) in
            if let error = error {
                completion(false, "Error fetching inventory: \(error.localizedDescription)")
                return
            }
            
            guard let document = document, document.exists else {
                // Document doesn't exist, create it with the new car
                userRef.setData([
                    "inventory": ["\(carName)#\(newCount)"]
                ]) { error in
                    if let error = error {
                        completion(false, "Error creating inventory: \(error.localizedDescription)")
                    } else {
                        completion(true, "Successfully added \(carName) to inventory!")
                    }
                }
                return
            }
            
            var inventory = document.data()?["inventory"] as? [String] ?? []
            
            // Find if this car already exists (with any count)
            if let existingIndex = inventory.firstIndex(where: { $0.hasPrefix("\(carName)#") }) {
                // Update the existing entry with new count
                inventory[existingIndex] = "\(carName)#\(newCount)"
            } else {
                // Add new car entry
                inventory.append("\(carName)#\(newCount)")
            }
            
            // Update the document
            userRef.updateData([
                "inventory": inventory
            ]) { error in
                if let error = error {
                    completion(false, "Error updating car count: \(error.localizedDescription)")
                } else {
                    completion(true, "Successfully updated \(carName) count to \(newCount)!")
                }
            }
        }
    }
    
    func fetchUserInventory(userId: String, completion: @escaping ([String]) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching user inventory: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let document = document, document.exists,
                  let data = document.data(),
                  let inventory = data["inventory"] as? [String] else {
                completion([])
                return
            }
            
            // Convert Firestore format back to local format
            var localInventory: [String] = []
            
            for item in inventory {
                if let delimiterIndex = item.firstIndex(of: "#"),
                   let countString = item[item.index(after: delimiterIndex)...].components(separatedBy: CharacterSet.decimalDigits.inverted).first,
                   let count = Int(countString) {
                    
                    let carName = String(item[..<delimiterIndex])
                    
                    // Create entries for each copy
                    for i in 1...count {
                        localInventory.append("\(carName)#\(i)")
                    }
                }
            }
            
            completion(localInventory)
        }
    }
    
    func equipCar(userId: String, carName: String, completion: @escaping (Bool, String) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        let isUnequipping = carName.isEmpty
        print(isUnequipping ? "Unequipping current car" : "Equipping car \(carName)")
        
        userRef.updateData(["equippedCar": carName]) { error in
            if let error = error {
                completion(false, "Error \(isUnequipping ? "unequipping" : "equipping") car: \(error.localizedDescription)")
            } else {
                let successMessage = isUnequipping ? "Successfully unequipped car!" : "Successfully equipped \(carName)!"
                completion(true, successMessage)
            }
        }
    }

    func fetchEquippedCar(userId: String, completion: @escaping (String?) -> Void) {
        let userRef = db.collection("users").document(userId)

        userRef.getDocument { (document, error) in
            if let error = error {
                print("Error fetching equipped car: \(error)")
                completion(nil)
                return
            }

            let equippedCar = document?.data()?["equippedCar"] as? String
            
            print("fetching car", equippedCar)
            completion(equippedCar)
        }
    }

    func saveRouteDetails(routeId: String, distance: Double, duration: Double, likes: Int, polyline: String, isPublic: Bool, routeImages: [String]?, userId: String, routeName: String, routeDescription: String, completion: @escaping () -> Void) {
        let routeRef = db.collection("routes").document(routeId)

        fetchEquippedCar(userId: userId) { equippedCar in
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
                "description": routeDescription,
                "equippedCar": equippedCar ?? ""
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

        
    }
    
//    func updateRouteImages(routeId: String, newImageUrl: String, completion: @escaping (Bool) -> Void) {
//        let routeRef = db.collection("routes").document(routeId)
//        
//        // First get the current document to access existing images
//        routeRef.getDocument { (document, error) in
//            if let document = document, document.exists {
//                // Get current images array or create a new one if it doesn't exist
//                var currentImages = document.data()?["routeImages"] as? [String] ?? []
//                
//                // Add the new image URL to the array
//                if(newImageUrl == "null"){
//                    print("image not found")
//                }else{
//                    currentImages.append(newImageUrl)
//                }
//                
//                
//                // Update only the routeImages field
//                routeRef.updateData([
//                    "routeImages": currentImages
//                ]) { error in
//                    if let error = error {
//                        print("Error updating route images: \(error)")
//                        completion(false)
//                    } else {
//                        print("Route images successfully updated!")
//                        completion(true)
//                    }
//                }
//            } else {
//                print("Document does not exist or error: \(error?.localizedDescription ?? "unknown error")")
//                completion(false)
//            }
//        }
//    }
    
    func removeRouteImage(routeId: String, imageUrlToRemove: String, completion: @escaping (Bool) -> Void) {
        let routeRef = db.collection("routes").document(routeId)
        
        // First get the current document to access existing images
        routeRef.getDocument { (document, error) in
            if let document = document, document.exists {
                // Get current images array or create a new one if it doesn't exist
                var currentImages = document.data()?["routeImages"] as? [String] ?? []
                
                // Remove the specific image URL from the array
                currentImages.removeAll { $0 == imageUrlToRemove }
                
                // Update only the routeImages field with the modified array
                routeRef.updateData([
                    "routeImages": currentImages
                ]) { error in
                    if let error = error {
                        print("Error removing route image: \(error)")
                        completion(false)
                    } else {
                        print("Route image successfully removed!")
                        completion(true)
                    }
                }
            } else {
                print("Document does not exist or error: \(error?.localizedDescription ?? "unknown error")")
                completion(false)
            }
        }
    }
    
//    func updateUserProfilePicture(userId: String, profilePictureURL: String, completion: @escaping (Bool) -> Void) {
//        let userRef = db.collection("users").document(userId)
//        
//        // Update the profilePictureURL field
//        userRef.updateData([
//            "profilePictureURL": profilePictureURL
//        ]) { error in
//            if let error = error {
//                print("Error updating profile picture: \(error)")
//                completion(false)
//            } else {
//                print("Profile picture successfully updated!")
//                completion(true)
//            }
//
//        }
//    }
    
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
            .order(by: "createdAt", descending: true)
            .limit(to: 15)
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
                                             
            let routes: [fb_Route] = documents.compactMap { document in
                    // Create fb_Route using your existing initializer
                 return fb_Route(id: document.documentID, data: document.data())
             }

             completion(routes)
            
            }
    }
    
    func getFriendsPosts(userId: String, completion: @escaping ([fb_Route]?) -> Void) {
        // First, get the user's friends list
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("Error fetching user data: \(error)")
                completion(nil)
                return
            }
            
            guard let data = snapshot?.data(),
                  let friendIds = data["friends"] as? [String] else {
                print("No friends found or invalid data")
                completion([])
                return
            }
            
            // If the user has no friends, return empty array
            if friendIds.isEmpty {
                completion([])
                return
            }
            
            // Now query for public routes from these friends
            let routesRef = self.db.collection("routes")
            routesRef
                .whereField("userid", in: friendIds)
                .whereField("public", isEqualTo: true)
                .order(by: "createdAt", descending: true)
                .limit(to: 20)
                .getDocuments { (snapshot, error) in
                    // The rest is the same as your getPublicRoutes function
                    if let error = error {
                        print("Error fetching friends' routes: \(error)")
                        completion(nil)
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        print("No friend routes found")
                        completion([])
                        return
                    }
                    
                    let routes: [fb_Route] = documents.compactMap { document in
                        // Same parsing logic as in getPublicRoutes
                        let data = document.data()
                        
                        // Parse Spotify songs data
                        var spotifySongs: [SpotifyTrack]? = nil
                        if let spotifySongsData = data["spotifySongs"] as? [[String: Any]] {
                            var songs: [SpotifyTrack] = []
                            for songData in spotifySongsData {
                                if let id = songData["id"] as? String,
                                   let name = songData["name"] as? String,
                                   let artists = songData["artists"] as? String,
                                   let albumName = songData["albumName"] as? String,
                                   let playedAt = songData["playedAt"] as? String {
                                    
                                    let albumImageUrl = songData["albumImageUrl"] as? String
                                    
                                    let track = SpotifyTrack(
                                        id: id,
                                        name: name,
                                        artists: artists,
                                        albumName: albumName,
                                        albumImageUrl: albumImageUrl,
                                        playedAt: playedAt
                                    )
                                    songs.append(track)
                                }
                            }
                            if !songs.isEmpty {
                                spotifySongs = songs
                            }
                        }
                        
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
                            name: data["name"] as? String ?? "",
                            spotifySongs: spotifySongs,  // Add the new parameter
                            equipedCar: data["equippedCar"] as? String ?? ""
                        )
                    }
                    
                    completion(routes)
                }
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
    
    func getCarForPost(routeId: String, userId: String, completion: @escaping (String) -> Void) {
        let car = db.collection("routes").document(routeId)
        
        car.getDocument { (document, error) in
            if let error = error {
                print("Error fetching car: \(error)")
                completion("")
                return
            }
            
            if let document = document, document.exists {
                let equippedCar = document.data()?["equipedCar"] as? String ?? ""
                completion(equippedCar)
            } else {
                completion("")
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
    
    func searchUsers(query: String, currentUserId: String, completion: @escaping ([User]) -> Void) {
        guard !query.isEmpty else {
            completion([])
            return
        }
        print("sending username search query")
        
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
    
    func saveSpotifySongsToRoute(routeID: UUID, songs: [SpotifyTrack], completion: @escaping (Error?) -> Void) {
        // Convert tracked songs to dictionary format for Firestore
        let routeID = routeID.uuidString
        let songsData = songs.map { song -> [String: Any] in
            var songDict: [String: Any] = [
                "id": song.id,
                "name": song.name,
                "artists": song.artists,
                "albumName": song.albumName,
                "playedAt": song.playedAt
            ]
            
            if let albumImageUrl = song.albumImageUrl {
                songDict["albumImageUrl"] = albumImageUrl
            }
            
            return songDict
        }
        
        // Update the route document with the songs
        db.collection("routes").document(routeID).updateData([
            "spotifySongs": songsData
        ]) { error in
            completion(error)
        }
    }
    
    // MARK: - Data Models
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
        var spotifySongs: [SpotifyTrack]?
        let equipedCar: String
        
        init(docID: String, createdAt: Date, distance: Double, duration: Double,
             likes: Int, polyline: String, isPublic: Bool, routeImages: [String],
             userId: String, description: String, name: String,
             spotifySongs: [SpotifyTrack]? = nil, equipedCar: String) {
            
            self.docID = docID
            self.createdAt = createdAt
            self.distance = distance
            self.duration = duration
            self.likes = likes
            self.polyline = polyline
            self.isPublic = isPublic
            self.routeImages = routeImages
            self.userId = userId
            self.description = description
            self.name = name
            self.spotifySongs = spotifySongs
            self.equipedCar = equipedCar
        }
    
        init(id: String, data: [String: Any]) {
            self.docID = id
            self.userId = data["userid"] as? String ?? ""
            self.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            self.distance = data["distance"] as? Double ?? 0.0
            self.duration = data["duration"] as? Double ?? 0.0
            self.polyline = data["polyline"] as? String ?? ""
            self.isPublic = data["public"] as? Bool ?? false
            self.name = data["name"] as? String ?? ""
            self.description = data["description"] as? String ?? ""
            self.likes = data["likes"] as? Int ?? 0
            self.routeImages = data["routeImages"] as? [String]
            self.equipedCar = data["equippedCar"] as? String ?? ""
            
            // Parse Spotify songs
            if let spotifySongsData = data["spotifySongs"] as? [[String: Any]] {
                var songs: [SpotifyTrack] = []
                for songData in spotifySongsData {
                    if let id = songData["id"] as? String,
                       let name = songData["name"] as? String,
                       let artists = songData["artists"] as? String,
                       let albumName = songData["albumName"] as? String,
                       let playedAt = songData["playedAt"] as? String {
                        
                        let albumImageUrl = songData["albumImageUrl"] as? String
                        
                        let track = SpotifyTrack(
                            id: id,
                            name: name,
                            artists: artists,
                            albumName: albumName,
                            albumImageUrl: albumImageUrl,
                            playedAt: playedAt
                        )
                        songs.append(track)
                    }
                }
                self.spotifySongs = songs
            } else {
                self.spotifySongs = nil
            }
        }
    }
}
