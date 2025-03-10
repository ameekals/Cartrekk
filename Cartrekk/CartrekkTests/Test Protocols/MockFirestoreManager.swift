//
//  MockFirestoreManager.swift
//  Cartrekk
//
//  Created by Sahil Tallam on 3/9/25.
//

import XCTest
@testable import Cartrekk

class MockFirestoreManager: ExploreViewModelFirestoreManaging {
    var postsToReturn: [fb_Route]?
    var commentsToReturn: [Comment]?
    var likeCountToReturn: Int = 0
    var usernameToReturn: String? = "MockUser"
    var getUserLikeStatusResult: Bool = false

    func getFriendsPosts(userId: String, completion: @escaping ([fb_Route]?) -> Void) {
        completion(postsToReturn)
    }
    
    func fetchUsernameSync(userId: String, completion: @escaping (String?) -> Void) {
        completion(usernameToReturn)
    }
    
    func getCommentsForRoute(routeId: String, completion: @escaping ([Comment]?) -> Void) {
        completion(commentsToReturn)
    }
    
    func addCommentToRoute(routeId: String, userId: String, text: String, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    func getLikeCount(routeId: String, completion: @escaping (Int) -> Void) {
        completion(likeCountToReturn)
    }
    
    func handleLike(routeId: String, userId: String, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }
    
    func getUserLikeStatus(routeId: String, userId: String, completion: @escaping (Bool) -> Void) {
        completion(getUserLikeStatusResult)
    }
}
