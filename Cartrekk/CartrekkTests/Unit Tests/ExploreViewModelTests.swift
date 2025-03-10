import XCTest
@testable import Cartrekk

class ExploreViewModelTests: XCTestCase {
    var viewModel: ExploreViewModel!
    var mockDB: MockFirestoreManager!

    override func setUp() {
        super.setUp()
        mockDB = MockFirestoreManager()
        viewModel = ExploreViewModel(db: mockDB)
    }
    
    override func tearDown() {
        viewModel = nil
        mockDB = nil
        super.tearDown()
    }
    
    // MARK: - Load Friends Posts
    func testLoadFriendsPosts() async throws {
        let dummyRoute = fb_Route(
            docID: "abcd",
            createdAt: Date(),
            distance: 100.0,
            duration: 60.0,
            likes: 5,
            polyline: "dummyPolyline",
            isPublic: true,
            routeImages: ["photo1.png"],
            userId: "user1",
            description: "This is a test post",
            name: "Test Post",
            equipedCar: "Legendary"
        )
        mockDB.postsToReturn = [dummyRoute]
        
        await viewModel.loadFriendsPosts(userId: "user1")
        try await Task.sleep(nanoseconds: 500_000_000)
        
        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertEqual(viewModel.posts.first?.id, "abcd")
        XCTAssertEqual(viewModel.posts.first?.photos, ["photo1.png"])
        XCTAssertEqual(viewModel.posts.first?.likes, 5)
        XCTAssertEqual(viewModel.posts.first?.username, "user1")
    }
    
    // MARK: - Add Comment
    func testAddComment() async {
        let dummyPost = Post(
            id: "post1",
            route: Route(id: UUID(), date: Date(), coordinates: []),
            photos: ["photo1.png"],
            likes: 5,
            comments: [],
            polyline: "dummyPolyline",
            userid: "user1",
            username: "TestUser",
            name: "Test Post",
            description: "This is a test post",
            distance: 100.0,
            duration: 60.0,
            car: "Test Car"
        )
        viewModel.posts = [dummyPost]
        
        await viewModel.addComment(postId: "post1", userId: "user1", username: "TestUser", text: "Great post!")
        
        XCTAssertEqual(viewModel.posts.first?.comments.count, 1)
        XCTAssertEqual(viewModel.posts.first?.comments.first?.text, "Great post!")
    }

    // MARK: - Test Load Comments
        func testLoadCommentsForPost() async throws {
            let dummyPost = Post(
                id: "post2",
                route: Route(id: UUID(), date: Date(), coordinates: []),
                photos: ["image.png"],
                likes: 3,
                comments: [],
                polyline: "polylineString",
                userid: "user2",
                username: "user2",
                name: "Route Two",
                description: "Second route",
                distance: 200.0,
                duration: 120.0,
                car: "Test Car"
            )
            viewModel.posts = [dummyPost]
            
            let dummyComment = Comment(
                id: "c1",
                userId: "user2",
                username: "Commenter",
                text: "Nice route!",
                timestamp: Date()
            )
            mockDB.commentsToReturn = [dummyComment]
            
            await viewModel.loadCommentsForPost(post: dummyPost)
            
            XCTAssertEqual(viewModel.posts.first?.comments.count, 1)
            XCTAssertEqual(viewModel.posts.first?.comments.first?.text, "Nice route!")
        }
        
        // MARK: - Test Like Post
        func testLikePostSync() {
            let dummyPost = Post(
                id: "post3",
                route: Route(id: UUID(), date: Date(), coordinates: []),
                photos: ["image.png"],
                likes: 10,
                comments: [],
                polyline: "polylineString",
                userid: "user3",
                username: "TestUser",
                name: "Route Three",
                description: "Third route",
                distance: 300.0,
                duration: 180.0,
                car: "Test Car"
            )
            viewModel.posts = [dummyPost]
            
            viewModel.likePost(postId: "post3")
            
            XCTAssertEqual(viewModel.posts.first?.likes, 11)
        }
        
        // MARK: - Test Update Likes
        func testUpdateLikesForPost() async throws {
            let dummyPost = Post(
                id: "post4",
                route: Route(id: UUID(), date: Date(), coordinates: []),
                photos: ["image.png"],
                likes: 0,
                comments: [],
                polyline: "polylineString",
                userid: "user4",
                username: "TestUser",
                name: "Route Four",
                description: "Fourth route",
                distance: 400.0,
                duration: 240.0,
                car: "Test Car"
            )
            viewModel.posts = [dummyPost]
            
            mockDB.likeCountToReturn = 42
            
            await viewModel.updateLikesForPost(postId: "post4")
            try await Task.sleep(nanoseconds: 300_000_000)
            
            XCTAssertEqual(viewModel.posts.first?.likes, 42)
        }
        
        // MARK: - Test Like Post (async)
        func testAsyncLikePost() async throws {
            let dummyPost = Post(
                id: "post5",
                route: Route(id: UUID(), date: Date(), coordinates: []),
                photos: ["image.png"],
                likes: 7,
                comments: [],
                polyline: "polylineString",
                userid: "user5",
                username: "TestUser",
                name: "Route Five",
                description: "Fifth route",
                distance: 500.0,
                duration: 300.0,
                car: "Test Car"
            )
            viewModel.posts = [dummyPost]
            
            mockDB.likeCountToReturn = 8
            
            await viewModel.likePost(postId: "post5", userId: "user5")
            try await Task.sleep(nanoseconds: 300_000_000)
            
            XCTAssertEqual(viewModel.posts.first?.likes, 8)
        }
        
        // MARK: - Test checkUserLikeStatus
        func testCheckUserLikeStatus() {
            mockDB.getUserLikeStatusResult = true
            
            let expectation = expectation(description: "UserLikeStatus")
            
            viewModel.checkUserLikeStatus(postId: "post6", userId: "user6") { isLiked in
                XCTAssertTrue(isLiked)
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 1.0)
        }
}
