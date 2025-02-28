//
//  FriendsView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 2/28/25.
//

import SwiftUI


// Friends view with tabs for different sections
struct FriendsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var friendsManager = FriendsManager()
    @State private var selectedTab = 0
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                // Custom tab selection
                HStack(spacing: 0) {
                    TabButton(title: "Friends", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    
                    TabButton(title: "Requests", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    
                    TabButton(title: "Find", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                }
                .padding(.top, 10)
                
                TabView(selection: $selectedTab) {
                    // Friends list tab
                    FriendsListView(friends: friendsManager.friends)
                        .environmentObject(friendsManager)
                        .tag(0)
                    
                    // Friend requests tab
                    RequestsView(requests: friendsManager.pendingRequests)
                        .environmentObject(friendsManager)
                        .tag(1)
                    
                    // Find friends tab
                    FindFriendsView(searchText: $searchText)
                        .environmentObject(friendsManager)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationTitle("Friends")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .onAppear {
                if let userId = authManager.userId {
                    friendsManager.loadFriends(userId: userId)
                    friendsManager.loadPendingRequests(userId: userId)
                }
            }
        }
        .environmentObject(friendsManager) // Add this to pass friendsManager to all child views
    }
}

// Tab button for the friends view
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .foregroundColor(isSelected ? .white : .gray)
                .background(isSelected ? Color.blue : Color.clear)
                .cornerRadius(isSelected ? 0 : 0)
        }
    }
}

// Friends list view
struct FriendsListView: View {
    let friends: [Friend]
    
    var body: some View {
        if friends.isEmpty {
            VStack {
                Spacer()
                Text("You don't have any friends yet")
                    .foregroundColor(.gray)
                Spacer()
            }
        } else {
            List {
                ForEach(friends) { friend in
                    FriendRow(friend: friend)
                }
            }
        }
    }
}

// Friend request view
struct RequestsView: View {
    let requests: [FriendRequest]
    
    var body: some View {
        if requests.isEmpty {
            VStack {
                Spacer()
                Text("No pending friend requests")
                    .foregroundColor(.gray)
                Spacer()
            }
        } else {
            List {
                ForEach(requests) { request in
                    RequestRow(request: request)
                }
            }
        }
    }
}

// Find friends view
struct FindFriendsView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Binding var searchText: String
    @State private var searchResults: [User] = []
    @State private var isSearching = false
    
    var body: some View {
        VStack {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search by username", text: $searchText)
                    .onChange(of: searchText) { newValue in
                        if !newValue.isEmpty {
                            searchUsers(query: newValue)
                        } else {
                            searchResults = []
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchResults = []
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 10)
            
            // Search results
            if searchResults.isEmpty && !searchText.isEmpty {
                if isSearching {
                    ProgressView("Searching...")
                        .padding()
                } else {
                    VStack {
                        Spacer()
                        Text("No users found")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            } else {
                List {
                    ForEach(searchResults) { user in
                        UserSearchRow(user: user)
                            .environmentObject(authManager)
                    }
                }
            }
        }
    }
    
    private func searchUsers(query: String) {
        guard let currentUserId = authManager.userId else { return }
        isSearching = true
        
        FirestoreManager.shared.searchUsers(query: query, currentUserId: currentUserId) { results in
            DispatchQueue.main.async {
                searchResults = results
                isSearching = false
            }
        }
    }
}

// Friend row component
struct FriendRow: View {
    let friend: Friend
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(friend.username)
                    .font(.headline)
            }
            
            Spacer()
            
            Button(action: {
                // View friend's profile
            }) {
                Text("View Profile")
                    .font(.caption)
                    .padding(6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

// Request row component
struct RequestRow: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var friendsManager: FriendsManager
    let request: FriendRequest
    @State private var isProcessing = false
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(request.username)
                    .font(.headline)
                Text("Wants to be friends")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isProcessing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .padding(.horizontal)
            } else {
                HStack {
                    Button(action: {
                        acceptRequest()
                    }) {
                        Text("Accept")
                            .font(.caption)
                            .padding(6)
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    
                    Button(action: {
                        declineRequest()
                    }) {
                        Text("Decline")
                            .font(.caption)
                            .padding(6)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private func acceptRequest() {
        guard let userId = authManager.userId else { return }
        isProcessing = true
        
        friendsManager.acceptRequest(currentUserId: userId, request: request)
        isProcessing = false
    }
    
    private func declineRequest() {
        guard let userId = authManager.userId else { return }
        isProcessing = true
        
        friendsManager.declineRequest(currentUserId: userId, request: request)
        isProcessing = false
    }
}

// User search result row
struct UserSearchRow: View {
    @EnvironmentObject var authManager: AuthenticationManager
    let user: User
    @State private var isSending = false
    @State private var requestSent = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .resizable()
                .frame(width: 40, height: 40)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading) {
                Text(user.username)
                    .font(.headline)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
            
            Button(action: {
                sendFriendRequest()
            }) {
                if requestSent {
                    Text("Request Sent")
                        .font(.caption)
                        .padding(6)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                } else if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .padding(6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                } else {
                    Text("Add Friend")
                        .font(.caption)
                        .padding(6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .disabled(requestSent || isSending)
        }
        .padding(.vertical, 4)
    }
    
    private func sendFriendRequest() {
        guard let currentUserId = authManager.userId else { return }
        isSending = true
        errorMessage = nil
        
        FirestoreManager.shared.sendFriendRequest(from: currentUserId, to: user.username) { success, error in
            DispatchQueue.main.async {
                isSending = false
                if success {
                    requestSent = true
                } else if let error = error {
                    errorMessage = error
                }
            }
        }
    }
}

// Model objects (would be implemented in separate files)
class FriendsManager: ObservableObject {
    @Published var friends: [Friend] = []
    @Published var pendingRequests: [FriendRequest] = []
    
    func loadFriends(userId: String) {
        FirestoreManager.shared.loadFriends(userId: userId) { [weak self] loadedFriends in
            DispatchQueue.main.async {
                self?.friends = loadedFriends
            }
        }
    }
    
    func loadPendingRequests(userId: String) {
        FirestoreManager.shared.loadPendingRequests(userId: userId) { [weak self] requests in
            DispatchQueue.main.async {
                self?.pendingRequests = requests
            }
        }
    }
    
    func acceptRequest(currentUserId: String, request: FriendRequest) {
        FirestoreManager.shared.acceptFriendRequest(currentUserId: currentUserId, senderId: request.senderId) { success, error in
            if success {
                DispatchQueue.main.async { [weak self] in
                    // Reload both friends and requests
                    self?.loadFriends(userId: currentUserId)
                    self?.loadPendingRequests(userId: currentUserId)
                }
            } else if let error = error {
                print(error)
            }
        }
    }
    
    func declineRequest(currentUserId: String, request: FriendRequest) {
        FirestoreManager.shared.declineFriendRequest(currentUserId: currentUserId, senderId: request.senderId) { success, error in
            if success {
                DispatchQueue.main.async { [weak self] in
                    self?.loadPendingRequests(userId: currentUserId)
                }
            } else if let error = error {
                print(error)
            }
        }
    }
}

struct Friend: Identifiable {
    let id: String
    let username: String
}

struct FriendRequest: Identifiable {
    let id: String
    let username: String
    let senderId: String
}

struct User: Identifiable {
    let id: String
    let username: String
}
