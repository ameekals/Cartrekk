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
    private let db = Firestore.firestore()
    
    func getRoutesForUser(userId: String, completion: @escaping ([fb_Route]?) -> Void) {
        let routesRef = db.collection("routes")
        
        routesRef.whereField("userid", isEqualTo: userId).getDocuments(source: .default) { (snapshot, error) in
            if let error = error {
                print("Error fetching routes: \(error)")
                completion(nil)
                return
            }
            
            guard let documents = snapshot?.documents else {
                print("No routes found for user: \(userId)")
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
                    userId: data["userid"] as? String ?? ""
                )
            }
            
            completion(routes)
        }
    }
    
    
    
    // 🔹 Function to save route details
    func saveRouteDetails(routeId: String, distance: Double, duration: Double, likes: Int, polyline: String, isPublic: Bool, routeImages: [String]?, userId: String) {
        let routeRef = db.collection("routes").document(routeId)

        let data: [String: Any] = [
            "createdAt": Timestamp(date: Date()),  // Stores current time
            "distance": distance,
            "duration": duration,
            "likes": likes,
            "polyline": polyline,
            "public": isPublic,
            "routeImages": routeImages as Any, // Store array or nil
            "userid": userId
        ]

        routeRef.setData(data) { error in
            if let error = error {
                print("Error saving route: \(error)")
            } else {
                print("Route successfully saved!")
            }
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
    }
    

}


