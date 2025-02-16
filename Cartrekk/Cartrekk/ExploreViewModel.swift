import Foundation

class ExploreViewModel: ObservableObject {
    @Published var posts: [Post] = []

    init() {
        loadMockPosts()
    }

    private func loadMockPosts() {
        let nycToSfCoordinates = [
            RouteCoordinate(latitude: 40.712776, longitude: -74.005974, timestamp: Date()),
            RouteCoordinate(latitude: 39.099724, longitude: -94.578331, timestamp: Date().addingTimeInterval(600)),
            RouteCoordinate(latitude: 37.774929, longitude: -122.419418, timestamp: Date().addingTimeInterval(1200))
        ]
        let routeNYCtoSF = Route(id: UUID(), date: Date(), coordinates: nycToSfCoordinates)

        let laToHoustonCoordinates = [
            RouteCoordinate(latitude: 34.052235, longitude: -118.243683, timestamp: Date()),
            RouteCoordinate(latitude: 32.776665, longitude: -96.796989, timestamp: Date().addingTimeInterval(600)),
            RouteCoordinate(latitude: 29.760427, longitude: -95.369804, timestamp: Date().addingTimeInterval(1200))
        ]
        let routeLAtoHouston = Route(id: UUID(), date: Date(), coordinates: laToHoustonCoordinates)

        posts = [
            Post(
                id: "1",
                route: routeNYCtoSF,
                photos: [
                    "https://media.istockphoto.com/id/1320137259/photo/three-best-friends-enjoying-traveling-at-vacation-in-the-car.jpg?s=612x612&w=0&k=20&c=IlLp43PybVon6EK5GlB_j6FDfz95JE1tauqHLQ-Da5A=",
                    "https://media.istockphoto.com/id/1445128149/photo/travel-road-trip-and-black-people-couple-driving-by-countryside-for-holiday-journey-and.jpg?s=612x612&w=0&k=20&c=WMUcjTHQo4A4VdyDAeJ_Vgm7z31vLPgEc97OI2bdL5I="
                ],
                likes: 10,
                comments: [
                    Comment(id: "1", userId: "2", username: "Alice", text: "Epic cross-country trip!", timestamp: Date()),
                    Comment(id: "2", userId: "3", username: "Bob", text: "I've always wanted to do this!", timestamp: Date())
                ]
            ),
            Post(
                id: "2",
                route: routeLAtoHouston,
                photos: [
                    "https://media.istockphoto.com/id/1053329198/photo/group-of-people-travel-by-car.jpg?s=612x612&w=0&k=20&c=F6_ju7Gl6ma7Hq1Q1fl9bhsdwxHbSKEDTRgd6OZAR_E=",
                    "https://t3.ftcdn.net/jpg/01/21/91/82/360_F_121918209_XbgrZSWb05mdsTnFEIxpa4ZcCWugT0Eq.jpg"
                ],
                likes: 7,
                comments: [
                    Comment(id: "3", userId: "4", username: "Charlie", text: "Houston road trips are fun!", timestamp: Date())
                ]
            )
        ]
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
