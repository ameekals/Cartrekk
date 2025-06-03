//
//  GarageView.swift
//  Cartrekk
//
//  Created by Ameek Singh on 2/17/25.
//

import SwiftUI
import SceneKit

struct GarageView: View {
    @ObservedObject var garageManager = GarageManager.shared
    @State private var selectedCarIndex: Int? = nil
    @State private var currentCarouselIndex: Int = 0
    @State private var carouselScenes: [SCNScene?] = []
    @State private var dragOffset: CGFloat = 0
    @State private var showTutorial: Bool = false
    @State private var showCaseOpening: Bool = false
    @State private var caseOpeningResult: String? = nil
    @State private var showCaseResult: Bool = false
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Grid layout configuration
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            mainContentView
            
            // Case Opening Animation Overlay
            if showCaseOpening {
                caseOpeningView
            }
        }
        .onAppear {
            if let userId = authManager.userId {
                garageManager.fetchEquippedCar(userId: userId)
            }
        }
        .navigationTitle("Garage")
        .navigationBarBackButtonHidden(selectedCarIndex != nil || showCaseOpening)
        .toolbar {
            // Back button for 3D carousel view
            if selectedCarIndex != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    backToGridButton
                }
            }
            
            // Back button for case opening (when result is shown)
            if showCaseOpening && showCaseResult {
                ToolbarItem(placement: .navigationBarLeading) {
                    backFromCaseOpeningButton
                }
            }
            
            // Tutorial button for grid view
            if !showCaseOpening && selectedCarIndex == nil {
                ToolbarItem(placement: .navigationBarTrailing) {
                    tutorialButton
                }
            }
        }
        .onTapGesture {
            if showTutorial {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showTutorial = false
                }
            }
        }
    }
    
    // MARK: - Main Content View
    @ViewBuilder
    private var mainContentView: some View {
        VStack {
            if selectedCarIndex != nil {
                carouselContentView
            } else {
                gridContentView
            }
        }
    }
    
    // MARK: - Carousel Content View
    @ViewBuilder
    private var carouselContentView: some View {
        // 3D Carousel View
        Car3DCarouselView(
            currentIndex: $currentCarouselIndex,
            scenes: carouselScenes,
            allCars: getAllCarsForCarousel(),
            unlockedCars: Set(garageManager.getUniqueUnlockedCars()),
            onSwipe: { direction in
                handleCarouselSwipe(direction: direction)
            }
        )
        .frame(height: 500)
        
        // Selected car info
        selectedCarInfoView
    }
    
    // MARK: - Selected Car Info View
    @ViewBuilder
    private var selectedCarInfoView: some View {
        let allCars = getAllCarsForCarousel()
        let currentCarName = allCars[currentCarouselIndex]
        let isUnlocked = garageManager.getUniqueUnlockedCars().contains(currentCarName)
        
        if isUnlocked {
            equipUnequipButton(for: currentCarName)
        } else {
            lockedCarIndicator
        }
    }
    
    // MARK: - Equip/Unequip Button
    @ViewBuilder
    private func equipUnequipButton(for carName: String) -> some View {
        Button(action: {
            if garageManager.equippedCar == carName {
                garageManager.equipCar(userId: authManager.userId ?? "", carName: "")
            } else {
                garageManager.equipCar(userId: authManager.userId ?? "", carName: carName)
            }
        }) {
            Text(garageManager.equippedCar == carName ? "Unequip Car" : "Equip Car")
                .font(.title2)
                .padding()
                .frame(maxWidth: .infinity)
                .background(garageManager.equippedCar == carName ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Locked Car Indicator
    @ViewBuilder
    private var lockedCarIndicator: some View {
        VStack {
            Image(systemName: "lock.fill")
                .font(.system(size: 30))
                .foregroundColor(.gray)
            Text("Car Locked")
                .font(.headline)
                .foregroundColor(.gray)
            Text("Unlock this car to equip it")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    // MARK: - Grid Content View
    @ViewBuilder
    private var gridContentView: some View {
        ZStack(alignment: .topTrailing) {
            carGridScrollView
            tutorialDropdownView
        }
        
        Spacer() // Push button to bottom
        unlockButton
    }
    
    // MARK: - Car Grid Scroll View
    @ViewBuilder
    private var carGridScrollView: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(garageManager.getAllCars(), id: \.self) { carName in
                    let isUnlocked = garageManager.getUniqueUnlockedCars().contains(carName)
                    let isEquipped = garageManager.equippedCar == carName
                    let rarity = garageManager.getCarRarity(for: carName)
                    let duplicateCount = garageManager.getDuplicateCount(for: carName)
                    
                    CarBoxView(
                        carName: carName,
                        isUnlocked: isUnlocked,
                        isEquipped: isEquipped,
                        rarity: rarity,
                        duplicateCount: duplicateCount,
                        action: {
                            selectCar(carName: carName)
                        }
                    )
                }
            }
            .padding()
            .padding(.bottom, 80) // Add bottom padding to prevent overlap with button
        }
    }
    
    // MARK: - Tutorial Dropdown View
    @ViewBuilder
    private var tutorialDropdownView: some View {
        if showTutorial {
            VStack {
                HStack {
                    Spacer()
                    TutorialDropdownView(
                        usablePoints: garageManager.usableMiles,
                        onDismiss: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showTutorial = false
                            }
                        }
                    )
                }
                .padding(.top, 8) // Small offset from navigation bar
                .padding(.trailing, 16) // Align with button position
                Spacer()
            }
            .transition(.asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.8, anchor: .topTrailing)),
                removal: .opacity.combined(with: .scale(scale: 0.8, anchor: .topTrailing))
            ))
        }
    }
    
    // MARK: - Unlock Button
    @ViewBuilder
    private var unlockButton: some View {
        ZStack {
            Button(action: { unlockCarWithAnimation(userId: authManager.userId!) }) {
                Text("Unlock Car")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(garageManager.usableMiles >= 25 ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .disabled(garageManager.usableMiles < 25)
            .overlay(
                // Lock overlay directly on the button
                garageManager.usableMiles < 25 ?
                lockOverlay : nil
            )
        }
        .padding()
    }
    
    // MARK: - Lock Overlay
    @ViewBuilder
    private var lockOverlay: some View {
        Color.black.opacity(0.6)
            .cornerRadius(10)
            .overlay(
                VStack {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                    Text("Locked")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            )
    }
    
    // MARK: - Case Opening View
    @ViewBuilder
    private var caseOpeningView: some View {
        CaseOpeningView(
            allCars: garageManager.getAllCars(),
            resultCar: caseOpeningResult ?? "redpink_truck",
            onComplete: {
                showCaseOpening = false
                showCaseResult = false
                // Navigate to the unlocked car's 3D view
                if let resultCar = caseOpeningResult {
                    let baseCarName = garageManager.getBaseCarName(from: resultCar)
                    selectCar(carName: baseCarName)
                }
                caseOpeningResult = nil
            },
            onResultShown: {
                showCaseResult = true
            }
        )
    }
    
    // MARK: - Toolbar Buttons
    @ViewBuilder
    private var backToGridButton: some View {
        Button(action: {
            selectedCarIndex = nil
            carouselScenes = []
            currentCarouselIndex = 0
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var backFromCaseOpeningButton: some View {
        Button(action: {
            showCaseOpening = false
            caseOpeningResult = nil
            showCaseResult = false
        }) {
            HStack {
                Image(systemName: "chevron.left")
                Text("Back")
            }
            .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var tutorialButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showTutorial.toggle()
            }
        }) {
            Image(systemName: "questionmark.circle.fill")
                .font(.system(size: 20))
                .foregroundColor(.blue)
        }
    }

    private func unlockCarWithAnimation(userId: String) {
        // Check if user has enough points before attempting unlock
        guard garageManager.usableMiles >= 25 else {
            print("Not enough points to unlock a car")
            return
        }
        
        // Pre-determine the result using existing logic but don't apply it yet
        let rarity = rollForRarityPreview()
        guard let availableCars = getAllCarsByRarity()[rarity],
              let selectedBaseCar = availableCars.randomElement() else {
            print("No cars available for rarity: \(rarity)")
            return
        }
        
        // Start the case opening animation
        caseOpeningResult = selectedBaseCar
        showCaseOpening = true
        
        // Actually unlock the car (this will be processed during animation)
        if let newCarMessage = garageManager.unlockCar(userId: userId) {
            print(newCarMessage)
        }
    }
    
    private func rollForRarityPreview() -> CarRarity {
        let randomNumber = Int.random(in: 1...100)
        switch randomNumber {
        case 1...60: return .common
        case 61...89: return .rare
        case 90...100: return .legendary
        default: return .common
        }
    }
    
    private func getAllCarsByRarity() -> [CarRarity: [String]] {
        return [
            .common: ["redpink_truck"],
            .rare: ["yellow_car_stripe", "ef"],
            .legendary: ["blue_car_hat"]
        ]
    }

    private func unlockCar(userId: String) {
        // Check if user has enough points before attempting unlock
        guard garageManager.usableMiles >= 25 else {
            print("Not enough points to unlock a car")
            return
        }
        
        if let newCarMessage = garageManager.unlockCar(userId: userId) {
            // Find the newly unlocked car and open its 3D view
            if let lastUnlockedCar = garageManager.unlockedCars.last {
                let baseCarName = garageManager.getBaseCarName(from: lastUnlockedCar)
                selectCar(carName: baseCarName)
            }
        } else {
            print("Failed to unlock car")
        }
    }
    
    private func selectCar(carName: String) {
        selectedCarIndex = 0 // Just mark that we're in 3D view
        let allCars = getAllCarsForCarousel()
        currentCarouselIndex = allCars.firstIndex(of: carName) ?? 0
        loadAllCarModels()
    }
    
    private func getAllCarsForCarousel() -> [String] {
        return garageManager.getAllCars()
    }
    
    private func handleCarouselSwipe(direction: SwipeDirection) {
        let allCars = getAllCarsForCarousel()
        
        switch direction {
        case .left:
            currentCarouselIndex = (currentCarouselIndex + 1) % allCars.count
        case .right:
            currentCarouselIndex = (currentCarouselIndex - 1 + allCars.count) % allCars.count
        }
    }

    private func loadAllCarModels() {
        let allCars = getAllCarsForCarousel()
        carouselScenes = Array(repeating: nil, count: allCars.count)
        
        // Load models asynchronously
        for (index, carName) in allCars.enumerated() {
            loadCarModel(for: carName, at: index)
        }
    }
    
    private func loadCarModel(for carName: String, at index: Int) {
        guard let url = Bundle.main.url(forResource: carName, withExtension: "ply") else {
            print("Error: \(carName).ply not found in App Bundle.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let carScene = try SCNScene(url: url, options: nil)
                
                DispatchQueue.main.async {
                    if let carNode = carScene.rootNode.childNodes.first {
                        carNode.eulerAngles.x = (-.pi / 2) + (.pi / 8)
                        carNode.eulerAngles.y = -(.pi / 8)
                        carNode.position.y -= 0.7
                        // Don't set scale here - it will be set dynamically in CarouselItemView
                    }
                    
                    // Add a camera positioned further back for better framing
                    let cameraNode = SCNNode()
                    cameraNode.camera = SCNCamera()
                    cameraNode.position = SCNVector3(x: 0, y: 0, z: 4) // Move camera further back
                    carScene.rootNode.addChildNode(cameraNode)
                    
                    if index < self.carouselScenes.count {
                        self.carouselScenes[index] = carScene
                    }
                }
            } catch {
                print("Failed to load \(carName).ply: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Tutorial Dropdown View
struct TutorialDropdownView: View {
    let usablePoints: Double
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("How to Use Garage")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            Divider()
            
            // Current Points Display
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("Current Points: \(usablePoints, specifier: "%.0f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
            
            // Tutorial Steps
            VStack(alignment: .leading, spacing: 10) {
                TutorialStepView(
                    stepNumber: "1",
                    title: "Unlock Cars",
                    description: "Use points from driving to unlock new cars (25 points each)",
                    icon: "star.circle.fill",
                    iconColor: .green
                )
                
                TutorialStepView(
                    stepNumber: "2",
                    title: "View & Equip",
                    description: "Click on any car to view 3D model and equip it if you own it",
                    icon: "cube.fill",
                    iconColor: .blue
                )
                
                TutorialStepView(
                    stepNumber: "3",
                    title: "Share with Friends",
                    description: "Equipped car will appear when sharing routes with friends",
                    icon: "person.2.fill",
                    iconColor: .purple
                )
            }
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
        .frame(maxWidth: 280)
    }
}

// MARK: - Tutorial Step View
struct TutorialStepView: View {
    let stepNumber: String
    let title: String
    let description: String
    let icon: String
    let iconColor: Color
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number circle
            ZStack {
                Circle()
                    .fill(iconColor)
                    .frame(width: 24, height: 24)
                Text(stepNumber)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: icon)
                        .foregroundColor(iconColor)
                        .font(.system(size: 14))
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
        }
    }
}

// MARK: - 3D Carousel View
struct Car3DCarouselView: View {
    @Binding var currentIndex: Int
    let scenes: [SCNScene?]
    let allCars: [String]
    let unlockedCars: Set<String>
    let onSwipe: (SwipeDirection) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var isCenterCarInteracting: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Previous car (left side)
                if allCars.count > 1 {
                    let prevIndex = (currentIndex - 1 + allCars.count) % allCars.count
                    CarouselItemView(
                        scene: scenes.indices.contains(prevIndex) ? scenes[prevIndex] : nil,
                        carName: allCars[prevIndex],
                        isUnlocked: unlockedCars.contains(allCars[prevIndex]),
                        scale: 0.6,
                        opacity: 0.5
                    )
                    .frame(width: geometry.size.width * 0.25)
                    .offset(x: dragOffset * 0.3)
                    .contentShape(Rectangle()) // Make entire area tappable/draggable
                }
                
                Spacer()
                
                // Current car (center)
                CarouselItemView(
                    scene: scenes.indices.contains(currentIndex) ? scenes[currentIndex] : nil,
                    carName: allCars[currentIndex],
                    isUnlocked: unlockedCars.contains(allCars[currentIndex]),
                    scale: 1.0,
                    opacity: 1.0
                )
                .frame(width: geometry.size.width * 0.5)
                .offset(x: dragOffset * 0.8)
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { _ in
                            isCenterCarInteracting = true
                        }
                        .onEnded { _ in
                            // Small delay to prevent immediate carousel interaction
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                isCenterCarInteracting = false
                            }
                        }
                )
                
                Spacer()
                
                // Next car (right side)
                if allCars.count > 1 {
                    let nextIndex = (currentIndex + 1) % allCars.count
                    CarouselItemView(
                        scene: scenes.indices.contains(nextIndex) ? scenes[nextIndex] : nil,
                        carName: allCars[nextIndex],
                        isUnlocked: unlockedCars.contains(allCars[nextIndex]),
                        scale: 0.6,
                        opacity: 0.5
                    )
                    .frame(width: geometry.size.width * 0.25)
                    .offset(x: dragOffset * 0.3)
                    .contentShape(Rectangle()) // Make entire area tappable/draggable
                }
            }
            .contentShape(Rectangle()) // Make the entire HStack draggable
            .simultaneousGesture(
                // Apply drag gesture only to left and right areas, not center
                DragGesture()
                    .onChanged { gesture in
                        // Don't process carousel drag if center car is being interacted with
                        guard !isCenterCarInteracting else { return }
                        
                        let location = gesture.location
                        let centerStart = geometry.size.width * 0.25
                        let centerEnd = geometry.size.width * 0.75
                        
                        // Only process drag if not in center car area
                        if location.x < centerStart || location.x > centerEnd {
                            isDragging = true
                            dragOffset = gesture.translation.width
                        }
                    }
                    .onEnded { gesture in
                        // Don't process carousel drag if center car is being interacted with
                        guard !isCenterCarInteracting else {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                            return
                        }
                        
                        let location = gesture.startLocation
                        let centerStart = geometry.size.width * 0.25
                        let centerEnd = geometry.size.width * 0.75
                        
                        // Only process swipe if drag started outside center car area
                        if location.x < centerStart || location.x > centerEnd {
                            isDragging = false
                            
                            let threshold: CGFloat = 50
                            let translationX = gesture.translation.width
                            
                            if translationX > threshold {
                                onSwipe(.right)
                            } else if translationX < -threshold {
                                onSwipe(.left)
                            }
                            
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        } else {
                            // Reset drag offset if gesture was in center
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentIndex)
    }
}

// MARK: - Carousel Item View
struct CarouselItemView: View {
    let scene: SCNScene?
    let carName: String
    let isUnlocked: Bool
    let scale: CGFloat
    let opacity: Double
    
    var body: some View {
        ZStack {
            if let scene = scene {
                SceneView(
                    scene: {
                        // Create a new scene and clone the car node
                        let newScene = SCNScene()
                        newScene.background.contents = UIColor.black
                        
                        // Clone the car node from the original scene
                        if let originalCarNode = scene.rootNode.childNodes.first {
                            let clonedCarNode = originalCarNode.clone()
                            
                            // Apply different scales based on position
                            let carScale: Float = scale == 1.0 ? 0.8 : 0.3 // 0.8 for center, 0.3 for sides
                            clonedCarNode.scale = SCNVector3(carScale, carScale, carScale)
                            
                            newScene.rootNode.addChildNode(clonedCarNode)
                        }
                        
                        // Add camera - positioned further back for center car to accommodate larger size
                        let cameraNode = SCNNode()
                        cameraNode.camera = SCNCamera()
                        let cameraDistance: Float = scale == 1.0 ? 6.0 : 4.0 // Further back for center car
                        cameraNode.position = SCNVector3(x: 0, y: 0, z: cameraDistance)
                        newScene.rootNode.addChildNode(cameraNode)
                        
                        return newScene
                    }(),
                    options: [.autoenablesDefaultLighting, .allowsCameraControl],
                    preferredFramesPerSecond: 60,
                    antialiasingMode: .multisampling4X,
                    delegate: nil,
                    technique: nil
                )
                .background(Color.black)
                .scaleEffect(scale)
                .opacity(opacity)
                .allowsHitTesting(scale == 1.0) // Allow interaction only with center car
            } else {
                // Loading placeholder
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .overlay(
                        ProgressView()
                            .scaleEffect(scale)
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
            
            // Locked overlay
            if !isUnlocked {
                Color.black.opacity(0.6)
                    .overlay(
                        VStack {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 30 * scale))
                                .foregroundColor(.white)
                            Text("Locked")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                    )
                    .scaleEffect(scale)
                    .opacity(opacity)
            }
        }
        .cornerRadius(10)
    }
}

// MARK: - Case Opening Animation View
struct CaseOpeningView: View {
    let allCars: [String]
    let resultCar: String
    let onComplete: () -> Void
    let onResultShown: () -> Void
    
    @State private var scrollOffset: CGFloat = 0
    @State private var animationPhase: CaseOpeningPhase = .initial
    @State private var showResult: Bool = false
    
    private let itemWidth: CGFloat = 120
    private let itemSpacing: CGFloat = 20
    private let totalItemWidth: CGFloat = 140 // itemWidth + itemSpacing
    
    enum CaseOpeningPhase {
        case initial, spinning, slowing, stopped, showingResult
    }
    
    var body: some View {
        ZStack {
            // Dark background overlay
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Text("Unlocking Car...")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Case opening container
                ZStack {
                    // Background for the case
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color(.systemGray6))
                        .frame(height: 200)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.yellow, lineWidth: 3)
                        )
                    
                    // Selection indicator (fixed in center)
                    VStack {
                        Triangle()
                            .fill(Color.red)
                            .frame(width: 20, height: 15)
                        Rectangle()
                            .fill(Color.red)
                            .frame(width: 3, height: 170)
                        Triangle()
                            .fill(Color.red)
                            .frame(width: 20, height: 15)
                            .rotationEffect(.degrees(180))
                    }
                    .zIndex(2)
                    
                    // Scrolling cars
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: itemSpacing) {
                            // Create multiple sets of cars for smooth scrolling
                            ForEach(0..<10, id: \.self) { setIndex in
                                ForEach(allCars, id: \.self) { carName in
                                    CaseItemView(
                                        carName: carName,
                                        rarity: getCarRarity(for: carName),
                                        isResult: carName == resultCar && setIndex == 5 // Result will be in the middle set
                                    )
                                    .frame(width: itemWidth)
                                }
                            }
                        }
                        .padding(.horizontal, UIScreen.main.bounds.width / 2 - itemWidth / 2)
                        .offset(x: scrollOffset)
                    }
                    .disabled(true)
                    .clipped()
                }
                .padding(.horizontal, 20)
                
                if showResult {
                    // Result display
                    VStack(spacing: 15) {
                        Text("Congratulations!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                        
                        Text("You unlocked a \(getCarRarity(for: resultCar).name) car!")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Button(action: onComplete) {
                            Text("View Car")
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 30)
                                .padding(.vertical, 12)
                                .background(Color.yellow)
                                .cornerRadius(25)
                        }
                        .padding(.top, 10)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(Color(.systemGray5).opacity(0.9))
                    )
                    .padding(.horizontal, 40)
                    .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func getCarRarity(for carName: String) -> CarRarity {
        let carsByRarity: [CarRarity: [String]] = [
            .common: ["redpink_truck"],
            .rare: ["yellow_car_stripe", "ef"],
            .legendary: ["blue_car_hat"]
        ]
        
        for (rarity, cars) in carsByRarity {
            if cars.contains(carName) {
                return rarity
            }
        }
        return .common
    }
    
    private func startAnimation() {
        // Calculate the position where the result car should stop in the center
        let resultPosition = calculateResultPosition()
        
        // Create a smooth deceleration animation using a custom timing curve
        // This simulates realistic physics where the spinning gradually slows down
        let totalDuration: Double = 4.0
        
        withAnimation(.timingCurve(0.25, 0.1, 0.25, 1.0, duration: totalDuration)) {
            scrollOffset = -resultPosition
        }
        
        // Show result after animation completes
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDuration + 0.2) {
            animationPhase = .showingResult
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                showResult = true
            }
            // Notify parent that result is now showing
            onResultShown()
        }
    }
    
    private func calculateResultPosition() -> CGFloat {
        // Find the position of the result car in the middle set (set index 5)
        let setIndex = 5
        let carIndex = allCars.firstIndex(of: resultCar) ?? 0
        let totalCarsBeforeResult = (setIndex * allCars.count) + carIndex
        return CGFloat(totalCarsBeforeResult) * totalItemWidth
    }
}

// MARK: - Case Item View
struct CaseItemView: View {
    let carName: String
    let rarity: CarRarity
    let isResult: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background with rarity color
                RoundedRectangle(cornerRadius: 10)
                    .fill(rarity.color.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(rarity.color, lineWidth: isResult ? 3 : 2)
                    )
                
                // Car image
                Image("\(carName)2d")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 60)
                
                // Glow effect for result
                if isResult {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yellow, lineWidth: 2)
                        .shadow(color: .yellow, radius: 10)
                }
            }
            .frame(height: 100)
            
            // Rarity indicator
            Text(rarity.name)
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(rarity == .common ? .black : .white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(rarity.color.opacity(0.9))
                .cornerRadius(8)
        }
        .scaleEffect(isResult ? 1.1 : 1.0)
    }
}

// MARK: - Triangle Shape for Selector
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

// MARK: - Swipe Direction Enum
enum SwipeDirection {
    case left, right
}

// Car Box Component (unchanged)
struct CarBoxView: View {
    let carName: String
    let isUnlocked: Bool
    let isEquipped: Bool
    let rarity: CarRarity
    let duplicateCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    // Car image - using 2D version (carName + "2d")
                    Image("\(carName)2d")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 100)
                        .opacity(isUnlocked ? 1.0 : 0.5)
                    
                    // Lock overlay for locked cars
                    if !isUnlocked {
                        Color.black.opacity(0.5)
                            .overlay(
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                    }
                    
                    // Equipped indicator
                    if isEquipped {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 24))
                                    .background(Circle().fill(Color.white).frame(width: 22, height: 22))
                                    .padding(5)
                            }
                            Spacer()
                        }
                    }
                    
                    // Duplicate count indicator (top left)
                    if isUnlocked && duplicateCount > 1 {
                        VStack {
                            HStack {
                                Text("x\(duplicateCount)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(8)
                                    .padding(4)
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    
                    // Rarity indicator in bottom right
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text(rarity.name)
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(rarity == .common ? .black : .white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(rarity.color.opacity(0.9))
                                .cornerRadius(4)
                                .padding(4)
                        }
                    }
                }
                .frame(width: 140, height: 100)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isEquipped ? Color.green :
                            (isUnlocked ? rarity.color : Color.gray),
                            lineWidth: isEquipped ? 3 : 2
                        )
                )
            }
        }
        .disabled(!isUnlocked)
    }
}
