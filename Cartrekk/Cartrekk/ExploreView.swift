//
//  ExploreView.swift
//  Cartrekk
//
//  Created by Sahil Tallam on 2/15/25.
//

import SwiftUI

struct ExploreView: View {
    @StateObject var viewModel = ExploreViewModel()

    var body: some View {
            NavigationView {
                List {
                    ForEach(viewModel.posts) { post in
                        PostView(post: post, viewModel: viewModel)
                            .listRowBackground(Color.clear)
                            .buttonStyle(PlainButtonStyle())
                    }
                }
                .navigationBarTitle("Explore")
                .task {
                    await viewModel.loadPublicPosts()
                }
            }
        }
}

