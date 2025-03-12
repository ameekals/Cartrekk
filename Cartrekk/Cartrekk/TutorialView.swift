//
//  TutorialView.swift
//  Cartrekk
//
//  Created by Tejas Vaze on 3/3/25.
//

import SwiftUI


class TutorialManager: ObservableObject {
    @Published var showTutorial: Bool = false
    
    func triggerTutorial() {
        showTutorial = true
    }
}

struct TutorialView: View {
    var onComplete: () -> Void
    @State private var currentPage = 0
    
    // Tutorial content - customize as needed
    let tutorialPages = [
        TutorialPage(
            title: "Welcome to CarTrekk",
            description: "Track your drives and share your adventures with friends.",
            imageName: "car.fill"
        ),
        TutorialPage(
            title: "Record Your Journeys",
            description: "Tap the car button to start recording a new route. The button turns red while recording.",
            imageName: "record.circle"
        ),
        TutorialPage(
            title: "Capture Moments",
            description: "Take photos during your journey to remember special moments and places.",
            imageName: "camera.circle.fill"
        ),
        TutorialPage(
            title: "Share Routes with Friends",
            description: "Publish your routes with friends to share your adventures",
            imageName: "map.fill"
        ),
        TutorialPage(
            title: "Open Lootboxes and Earn Rewards",
            description: "Use the miles you've driven to open lootboxes and earn rewards! Each mile opens 1 box",
            imageName: "gift.fill"
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                
                // App logo or icon
                Image(systemName: "car.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
                    .padding(.bottom, 40)
                
                // Current tutorial page content
                VStack(spacing: 20) {
                    Image(systemName: tutorialPages[currentPage].imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                        .foregroundColor(.white)
                        .padding()
                    
                    Text(tutorialPages[currentPage].title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(tutorialPages[currentPage].description)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                        .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Page indicators
                HStack(spacing: 8) {
                    ForEach(0..<tutorialPages.count, id: \.self) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                    }
                }
                .padding(.bottom, 20)
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        Button(action: {
                            withAnimation {
                                currentPage -= 1
                            }
                        }) {
                            Text("Previous")
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.gray.opacity(0.3))
                                .cornerRadius(10)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withAnimation {
                            if currentPage < tutorialPages.count - 1 {
                                currentPage += 1
                            } else {
                                onComplete()
                            }
                        }
                    }) {
                        Text(currentPage < tutorialPages.count - 1 ? "Next" : "Get Started")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 40)
            }
        }
    }
}

// Simple data structure for tutorial pages
struct TutorialPage {
    let title: String
    let description: String
    let imageName: String
}
