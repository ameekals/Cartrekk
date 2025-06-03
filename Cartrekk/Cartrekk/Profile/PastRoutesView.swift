//
//  PastRoutesView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 6/3/25.
//

import SwiftUI
import FirebaseAuth
import Firebase
import FirebaseFirestore
import GoogleSignIn
import UIKit
import Polyline
import MapKit

import SafariServices


// MARK: - Past Routes View
struct PastRoutesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @ObservedObject var garageManager = GarageManager.shared
    @StateObject private var viewModel = ProfileViewModel()
    
    var totalDistanceTraveled: Double {
        viewModel.routes.reduce(0) { $0 + $1.distance }
    }

    var body: some View {
        VStack {
            Text("Past Routes")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .padding(.top, 20)
            
            if viewModel.routes.isEmpty {
                Text("No past routes available.")
                    .foregroundColor(.gray)
                    .padding()
            } else {
                List(viewModel.routes, id: \.docID) { route in
                   RouteRow(route: route, onDelete: {
                       // Remove the route locally from viewModel.routes
                       if let index = viewModel.routes.firstIndex(where: { $0.docID == route.docID }) {
                           viewModel.routes.remove(at: index)
                       }
                   })
               }
               .background(Color.black)
            }
            
            Spacer()
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
        .padding()
        .onAppear {
            if let userId = authManager.userId {
                Task {
                    await viewModel.loadRoutes(userId: userId)
                    // Use this when tables per user are added
                    garageManager.fetchTotalMiles(userId: userId)
//                    garageManager.fetchTotalMiles(userId: "userid_1")
                }
            }
        }
    }
}

// MARK: - Route Row
struct RouteRow: View {
    let route: FirestoreManager.fb_Route
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isCurrentlyPublic: Bool
    @State private var showExpandedMap = false
    @State private var showFullSpotifyList = false
    // Add a callback for deletion
    var onDelete: () -> Void
    
    init(route: FirestoreManager.fb_Route, onDelete: @escaping () -> Void) {
        self.route = route
        self.onDelete = onDelete
        _isCurrentlyPublic = State(initialValue: route.isPublic)
    }
    
    @State private var showDeleteConfirmation = false
    @State private var showPostConfirmation = false
    @State private var isLiked = false
    @State private var showCommentsSheet = false
    @State private var routeComments: [Comment] = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Separate HStack for the header with delete button
            HStack {
                VStack(alignment: .leading) {
                    Text(formatDate(route.createdAt))
                        .font(.headline)
                }
                
                Spacer()
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .confirmationDialog(
                    "Delete Route",
                    isPresented: $showDeleteConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Delete", role: .destructive) {
                        Task {
                            if await viewModel.deleteRoute(routeId: route.docID) {
                                // Call the onDelete callback to notify parent view
                                onDelete()
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }
            
            // Route title if available
            let routeName = route.name
            if !routeName.isEmpty {
                Text(routeName)
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top, 4)
            }
            
            // Rest of the route information
            HStack {
                Text(String(format: "%.2f m", route.distance))
                Spacer()
                Text(formatDuration(route.duration))
            }
            .font(.subheadline)
            .foregroundColor(.gray)
            
            TabView {
                // Map view with the route
                let polyline = Polyline(encodedPolyline: route.polyline)
                
                if let locations = polyline.locations, !locations.isEmpty {
                    ZStack {
                        Map {
                            Marker("Start",
                                   coordinate: locations.first!.coordinate)
                            .tint(.green)
                            
                            Marker("End",
                                   coordinate: locations.last!.coordinate)
                            .tint(.red)
                            
                            MapPolyline(coordinates: locations.map { $0.coordinate })
                                .stroke(
                                    Color.blue.opacity(0.8),
                                    style: StrokeStyle(
                                        lineWidth: 4,
                                        lineCap: .butt,
                                        lineJoin: .round,
                                        miterLimit: 10
                                    )
                                )
                        }
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .allowsHitTesting(false) // Disable direct map interaction in carousel
                        
                        // Add a transparent overlay button that fills the entire map area
                        Button(action: {
                            showExpandedMap = true
                        }) {
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle()) // Important for hit testing
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .frame(height: 250)
                    // Present a full-screen map when tapped
                    .fullScreenCover(isPresented: $showExpandedMap) {
                        NavigationView {
                            Map {
                                Marker("Start",
                                       coordinate: locations.first!.coordinate)
                                .tint(.green)
                                
                                Marker("End",
                                       coordinate: locations.last!.coordinate)
                                .tint(.red)
                                
                                MapPolyline(coordinates: locations.map { $0.coordinate })
                                    .stroke(
                                        Color.blue.opacity(0.8),
                                        style: StrokeStyle(
                                            lineWidth: 4,
                                            lineCap: .butt,
                                            lineJoin: .round,
                                            miterLimit: 10
                                        )
                                    )
                            }
                            .navigationTitle("Route Map")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Close") {
                                        showExpandedMap = false
                                    }
                                }
                            }
                            .ignoresSafeArea(.all, edges: .bottom)
                        }
                    }
                }

                if let routeImages = route.routeImages, !routeImages.isEmpty {
                    ForEach(routeImages, id: \.self) { photoUrl in
                        AsyncImage(url: URL(string: photoUrl)) { image in
                            image.resizable()
                                .scaledToFit()
                                .frame(height: 250)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                    }
                }
                if let spotifySongs = route.spotifySongs, !spotifySongs.isEmpty {
                   SpotifyTracksPreview(tracks: spotifySongs, showFullList: $showFullSpotifyList)
                       .frame(height: 250)
               }
           }
           .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
           .frame(height: 250)

            
            HStack(spacing: 20) {
                // Likes display
                HStack {
                    Image(systemName: "heart")
                        .foregroundColor(.red)
                    Text("\(route.likes)")
                        .foregroundColor(.gray)
                }
                
                // Comments display with button to view
                Button(action: {
                    Task {
                        routeComments = await viewModel.loadCommentsForRoute(routeId: route.docID)
                        showCommentsSheet = true
                    }
                }) {
                    HStack {
                        Image(systemName: "message")
                        Text("Comments")
                            .foregroundColor(.gray)
                    }
                }
                .buttonStyle(.borderless)
                
                Spacer()
                
                // Public/Private toggle
                Button(action: {
                    print("Button tapped") // Debug print
                    showPostConfirmation = true
                }) {
                    HStack {
                        Image(systemName: isCurrentlyPublic ? "globe" : "globe.slash")
                        Text(isCurrentlyPublic ? "Public" : "Private")
                    }
                    .foregroundColor(isCurrentlyPublic ? .blue : .gray)
                }
                .buttonStyle(.borderless)
                .confirmationDialog(
                    isCurrentlyPublic ? "Make Private" : "Make Public",
                    isPresented: $showPostConfirmation
                ) {
                    Button(isCurrentlyPublic ? "Make Private" : "Make Public") {
                        // Toggle the UI state immediately
                        isCurrentlyPublic.toggle()
                        
                        // Update Firestore in background
                        Task {
                            await viewModel.togglePublicStatus(routeId: route.docID)
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        print("Cancel tapped") // Debug print
                    }
                }
            }
            
            .padding(.vertical, 8)
            
            // Route description if available
            let description = route.description
            if !description.isEmpty {
                Text(description)
                    .font(.body)
                    .padding(.vertical, 4)
            }
        }
        .sheet(isPresented: $showFullSpotifyList) {
           if let spotifySongs = route.spotifySongs, !spotifySongs.isEmpty {
               SpotifyTracksFullListView(tracks: spotifySongs)
                   .preferredColorScheme(.dark)
           }
       }
        .sheet(isPresented: $showCommentsSheet) {
            NavigationView {
                List {
                    if !routeComments.isEmpty {
                        ForEach(routeComments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.username)
                                    .fontWeight(.bold)
                                Text(comment.text)
                                Text(comment.timestamp, style: .relative)
                                    .foregroundColor(.gray)
                            }
                            .font(.caption)
                        }
                    } else {
                        Text("No comments yet")
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
                .navigationTitle("Comments")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Close") {
                            showCommentsSheet = false
                        }
                    }
                }
            }
        }
    }
    
    // Keep your existing helper functions
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatDuration(_ duration: Double) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
