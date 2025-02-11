//
//  CartrekkApp.swift
//  Cartrekk
//
//  Created by Ameek Singh on 1/18/25.
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn


class AppDelegate: NSObject, UIApplicationDelegate {
    
    var db : Firestore!
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        self.db = Firestore.firestore()
                // Example: Save route details
        saveRouteDetails(routeId: "testRoute123",
                         distance: 25.3,
                         duration: 45.2,
                         likes: 10045,
                         polyline: "clv~FtbxuOajAdfC^nk@feAxeAjhAgqA",
                         isPublic: true,
                         routeImages: nil,
                         userId: "userid_1")

        // Example: Fetch route details
        getRouteDetails(routeId: "testRoute123") { route in
            if let route = route {
                print("Fetched Route: \(route)")
            } else {
                print("Failed to fetch route.")
            }
        }
        
        return true
    }
    // 🔹 Function to fetch route details
    func getRouteDetails(routeId: String, completion: @escaping (fb_Route?) -> Void) {
        let routeRef = db.collection("routes").document(routeId)

        routeRef.getDocument { document, error in
            if let error = error {
                print("Error getting route: \(error)")
                completion(nil)
                return
            }

            if let document = document, document.exists,
               let data = document.data() {

                let route = fb_Route(
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                    distance: data["distance"] as? Double ?? 0.0,
                    duration: data["duration"] as? Double ?? 0.0,
                    likes: data["likes"] as? Int ?? 0,
                    polyline: data["polyline"] as? String ?? "",
                    isPublic: data["public"] as? Bool ?? false,
                    routeImages: data["routeImages"] as? [String] ?? nil,
                    userId: data["userid"] as? String ?? ""
                )

                print("Fetched Route: \(route)")
                completion(route)
            } else {
                print("Document does not exist.")
                completion(nil)
            }
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
}

// 🔹 Data Model
struct fb_Route {
    let createdAt: Date
    let distance: Double
    let duration: Double
    let likes: Int
    let polyline: String
    let isPublic: Bool
    let routeImages: [String]?
    let userId: String
}

@main
struct CartrekkApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
