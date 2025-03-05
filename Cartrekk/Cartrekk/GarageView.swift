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
    @State private var scene: SCNScene? = nil
    @State private var showUnlockAlert = false
    @State private var unlockedCar: String? = nil
    @EnvironmentObject var authManager: AuthenticationManager
    
    // Grid layout configuration
    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 16)
    ]
    
    var body: some View {
        VStack {
            // 3D Model View (shown when a car is selected)
            if let selectedIndex = selectedCarIndex, let scene = scene {
                SceneView(scene: scene, options: [.autoenablesDefaultLighting, .allowsCameraControl])
                    .frame(height: 300)
                    .cornerRadius(10)
                    .padding(.bottom)
                
                Text(garageManager.unlockedCars[selectedIndex])
                    .font(.headline)
                    .padding(.bottom)
                
                Button("Back to Garage") {
                    selectedCarIndex = nil
                }
                .padding(.bottom)
            } else {
                // Car Grid View
                if garageManager.unlockedCars.isEmpty {
                    Text("Unlock a car to view it!")
                        .font(.headline)
                        .foregroundColor(.gray)
                        .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(garageManager.getAllCars(), id: \.self) { carName in
                                let isUnlocked = garageManager.unlockedCars.contains(carName)
                                
                                CarBoxView(
                                    carName: carName,
                                    isUnlocked: isUnlocked,
                                    action: {
                                        if isUnlocked {
                                            selectCar(carName: carName)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }

                // Unlock Button
                Button(action: {unlockCar(userId: authManager.userId!)}) {
                    Text("Unlock Car")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(garageManager.usableMiles >= 1 ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .disabled(garageManager.usableMiles < 1)
                }
                .padding()
            }
        }
        .onAppear {
            selectedCarIndex = nil
        }
        .alert(isPresented: $showUnlockAlert) {
            Alert(
                title: Text("Car Unlocked!"),
                message: Text("\(unlockedCar ?? "a car")!"),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Garage")
    }
    
    private func unlockCar(userId: String) {
        if let newCar = garageManager.unlockCar(userId: userId) {
            unlockedCar = newCar
            showUnlockAlert = true
            // Don't immediately load the model, let user select from grid
        }
    }
    
    private func selectCar(carName: String) {
        guard let index = garageManager.unlockedCars.firstIndex(of: carName) else { return }
        selectedCarIndex = index
        loadCarModel()
    }
    
    private func loadCarModel() {
        guard let selectedIndex = selectedCarIndex else { return }
        guard selectedIndex < garageManager.unlockedCars.count else { return }
        
        let carName = garageManager.unlockedCars[selectedIndex]
        guard let url = Bundle.main.url(forResource: carName, withExtension: "ply") else {
            print("Error: \(carName).ply not found in App Bundle.")
            return
        }
        
        do {
            let carScene = try SCNScene(url: url, options: nil)
            DispatchQueue.main.async {
                self.scene = carScene
            }
        } catch {
            print("Failed to load \(carName).ply: \(error.localizedDescription)")
        }
    }
}

// Car Box Component
struct CarBoxView: View {
    let carName: String
    let isUnlocked: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack {
                ZStack {
                    // Car image
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
                }
                .frame(width: 140, height: 100)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isUnlocked ? Color.green : Color.gray, lineWidth: 2)
                )
                
                Text(carName)
                    .font(.caption)
                    .foregroundColor(isUnlocked ? .primary : .gray)
            }
        }
        .disabled(!isUnlocked)
    }
}
