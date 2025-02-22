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
    @State private var currentCarIndex = 0
    @State private var scene: SCNScene? = nil
    @State private var showUnlockAlert = false
    @State private var unlockedCar: String? = nil

    var body: some View {
        VStack {
            if garageManager.unlockedCars.isEmpty {
                Text("Unlock a car to view it!")
                    .font(.headline)
                    .foregroundColor(.gray)
            } else if let scene = scene {
                SceneView(scene: scene, options: [.autoenablesDefaultLighting, .allowsCameraControl])
                    .frame(height: 400)
                    .cornerRadius(10)
            }

            // Unlock Button
            Button(action: unlockCar) {
                Text("Unlock Car (\(garageManager.usableMiles, specifier: "%.0f") Points)")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(garageManager.usableMiles >= 100 ? Color.green : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(garageManager.usableMiles < 100)
            }
            .padding()

            // Navigation Arrows (Only if cars are unlocked)
            if !garageManager.unlockedCars.isEmpty {
                HStack {
                    Button(action: showPreviousCar) {
                        Image(systemName: "arrow.left.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    .disabled(currentCarIndex == 0)

                    Spacer()

                    Button(action: showNextCar) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    .disabled(currentCarIndex == garageManager.unlockedCars.count - 1)
                }
                .padding()
            }
        }
        .onAppear {
            loadCarModel()
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

    private func unlockCar() {
        if let newCar = garageManager.unlockCar() {
            unlockedCar = newCar
            showUnlockAlert = true
            loadCarModel()
        }
    }

    private func loadCarModel() {
        guard !garageManager.unlockedCars.isEmpty else { return }

        let carName = garageManager.unlockedCars[currentCarIndex]
        guard let url = Bundle.main.url(forResource: carName, withExtension: "obj") else {
            print("Error: \(carName).obj not found in App Bundle.")
            return
        }

        do {
            let carScene = try SCNScene(url: url, options: nil)
            DispatchQueue.main.async {
                self.scene = carScene
            }
        } catch {
            print("Failed to load \(carName).obj: \(error.localizedDescription)")
        }
    }

    private func showPreviousCar() {
        if currentCarIndex > 0 {
            currentCarIndex -= 1
            loadCarModel()
        }
    }

    private func showNextCar() {
        if currentCarIndex < garageManager.unlockedCars.count - 1 {
            currentCarIndex += 1
            loadCarModel()
        }
    }
}
