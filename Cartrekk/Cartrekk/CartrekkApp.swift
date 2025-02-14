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
import AWSClientRuntime
import AWSS3


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
    /*
    static func main() async {
        print("letS TRY S3")

        do {
            let names = try await getBucketNames()

            print("Found \(names.count) buckets:")
            for name in names {
                print("  \(name)")
            }
        } catch let error as AWSServiceError {
            print("An Amazon S3 service error occurred: \(error.message ?? "No details available")")
        } catch {
            print("An unknown error occurredddddddd: \(dump(error))")
        }
        print("done with allat")
    }
     */
}
