//
//  GarageView.swift
//  Cartrekk
//
//  Created by Ameek Singh on 2/17/25.
//

import Foundation
import SwiftUI
import SceneKit

struct GarageView: View {
    @State private var scene: SCNScene? = nil
    @State private var currentCarIndex = 0

    private let carModels = ["car1", "car2", "car3"] // List of available car models

    var body: some View {
        VStack {
            if let scene = scene {
                SceneView(scene: scene, options: [.autoenablesDefaultLighting, .allowsCameraControl])
                    .frame(height: 400)
                    .cornerRadius(10)
            } else {
                Text("Loading 3D Car...")
                    .font(.title2)
                    .foregroundColor(.gray)
            }

            HStack {
                // Previous Car Button
                Button(action: showPreviousCar) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                .disabled(currentCarIndex == 0) // Disable if already at the first car

                Spacer()

                // Next Car Button
                Button(action: showNextCar) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                }
                .disabled(currentCarIndex == carModels.count - 1) // Disable if already at the last car
            }
            .padding()
        }
        .onAppear {
            loadCarModel()
        }
        .navigationTitle("Garage")
    }

    // MARK: - Load 3D Car Model
    private func loadCarModel() {
        let carName = carModels[currentCarIndex]
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

    // MARK: - Navigation Actions
    private func showPreviousCar() {
        if currentCarIndex > 0 {
            currentCarIndex -= 1
            loadCarModel()
        }
    }

    private func showNextCar() {
        if currentCarIndex < carModels.count - 1 {
            currentCarIndex += 1
            loadCarModel()
        }
    }
}

