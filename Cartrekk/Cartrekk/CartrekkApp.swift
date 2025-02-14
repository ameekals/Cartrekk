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
        
        
        return true
    }
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
