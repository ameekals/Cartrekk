//
//  ExploreView.swift
//  Cartrekk
//
//  Created by Sahil Tallam on 2/15/25.
//

import SwiftUI

struct ExploreView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @StateObject var viewModel = ExploreViewModel()
    @State private var showFriendsSheet = false

    var body: some View {
        NavigationView {
            VStack {
                if viewModel.posts.isEmpty {
                    VStack {
                        Spacer()
                        Text("No posts from friends yet")
                            .foregroundColor(.gray)
                        Button("Find Friends") {
                            showFriendsSheet = true
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding()
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(viewModel.posts) { post in
                            PostView(post: post, viewModel: viewModel)
                                .listRowBackground(Color.clear)
                                .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            }
            .navigationBarTitle("Friends")
            .task {
                if let userId = authManager.userId {
                    await viewModel.loadFriendsPosts(userId: userId)
                }
            }
            .sheet(isPresented: $showFriendsSheet) {
                FriendsView()
                    .environmentObject(authManager)
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
