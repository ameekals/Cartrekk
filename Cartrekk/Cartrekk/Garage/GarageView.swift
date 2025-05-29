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
            if garageManager.unlockedCars.isEmpty {
                Text("Unlock a car to view it!")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding()
            } else if let selectedIndex = selectedCarIndex, let scene = scene {
                // 3D Model View (shown when a car is selected)
                SceneView(scene: scene, options: [.autoenablesDefaultLighting, .allowsCameraControl])
                    .frame(height: 400)
                    .cornerRadius(10)
                
                // Selected car info
                let currentCar = garageManager.unlockedCars[selectedIndex]
                let carRarity = garageManager.getCarRarity(for: currentCar)
                
                VStack(spacing: 8) {
                    Text(currentCar)
                        .font(.headline)
                    
                    // Rarity indicator
                    Text(carRarity.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(carRarity.color.opacity(0.8))
                        .cornerRadius(8)
                }
                .padding(.top)
                
                // Equip/Unequip Button
                Button(action: {
                    if garageManager.equippedCar == currentCar {
                        garageManager.equipCar(userId: authManager.userId ?? "", carName: "")
                    } else {
                        garageManager.equipCar(userId: authManager.userId ?? "", carName: currentCar)
                    }
                }) {
                    Text(garageManager.equippedCar == currentCar ? "Unequip Car" : "Equip Car")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(garageManager.equippedCar == currentCar ? Color.red : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
                
            } else {
                // Car Grid View
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(garageManager.getAllCars(), id: \.self) { carName in
                            let isUnlocked = garageManager.unlockedCars.contains(carName)
                            let isEquipped = garageManager.equippedCar == carName
                            let rarity = garageManager.getCarRarity(for: carName)
                            
                            CarBoxView(
                                carName: carName,
                                isUnlocked: isUnlocked,
                                isEquipped: isEquipped,
                                rarity: rarity,
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

            // Unlock Button - only visible in inventory view
            if selectedCarIndex == nil {
                Button(action: { unlockCar(userId: authManager.userId!) }) {
                    Text("Unlock Car") // (\(garageManager.usableMiles, specifier: "%.0f") Points)")
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
            if let userId = authManager.userId {
                garageManager.fetchEquippedCar(userId: userId)
            }
        }
        .alert(isPresented: $showUnlockAlert) {
            Alert(
                title: Text("Car Unlocked!"),
                message: Text("\(unlockedCar ?? "a car")!"),
                dismissButton: .default(Text("OK"))
            )
        }
        .navigationTitle("Garage")
        .navigationBarBackButtonHidden(selectedCarIndex != nil)
        .toolbar {
            if selectedCarIndex != nil {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        selectedCarIndex = nil
                    }) {
                        HStack {
                            Image(systemName: "chevron.left")
                            Text("Garage")
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    private func unlockCar(userId: String) {
        if let newCar = garageManager.unlockCar(userId: userId) {
            unlockedCar = newCar
            showUnlockAlert = true
            
            // If we're in the detail view, load the new car if that's what was unlocked
            if let selectedIndex = selectedCarIndex {
                loadCarModel()
            }
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
                if let carNode = carScene.rootNode.childNodes.first {
                    carNode.eulerAngles.x = (-.pi / 2) + (.pi / 8)
                    carNode.eulerAngles.y = -(.pi / 8)
                    carNode.position.y -= 0.7 // Move the model down
                }
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
    let isEquipped: Bool
    let rarity: CarRarity
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
                
                Text(carName)
                    .font(.caption)
                    .foregroundColor(isUnlocked ? .primary : .gray)
            }
        }
        .disabled(!isUnlocked)
    }
}
