//
//  GarageManager.swift
//  Cartrekk
//
//  Created by Ameek Singh on 2/17/25.
//

import FirebaseFirestore
import FirebaseAuth
import SwiftUI

class GarageManager: ObservableObject {
    static let shared = GarageManager()

    @Published var totalMiles: Double = 0.0
    @Published var usableMiles: Double = 0.0
    @Published var unlockedCars: [String] = []
    @Published var equippedCar: String? = nil

    // Updated to 3-tier system
    private let allCarsByRarity: [CarRarity: [String]] = [
        .common: ["redpink_truck"],
        .rare: ["yellow_car_stripe", "ef"],
        .legendary: ["blue_car_hat"]
    ]

    private init() {
        if let userId = Auth.auth().currentUser?.uid {
            fetchTotalMiles(userId: userId)
        } else {
            print("No logged-in user. Cannot fetch total miles.")
        }
    }
    
    func getAllCars() -> [String] {
        return ["redpink_truck", "yellow_car_stripe", "ef", "blue_car_hat"]
    }

    // Get rarity for a specific car
    func getCarRarity(for carName: String) -> CarRarity {
        for (rarity, cars) in allCarsByRarity {
            if cars.contains(carName) {
                return rarity
            }
        }
        return .common // Default fallback
    }

    func fetchTotalMiles(userId: String) {
        FirestoreManager.shared.fetchTotalDistanceForUser(userId: userId) { [weak self] totalDistance in
            guard let self = self, let totalDistance = totalDistance else {
                print("Failed to fetch total miles.")
                return
            }
            FirestoreManager.shared.fetchUsableDistanceForUser(userId: userId) { [weak self] used_distance in
                guard let self = self, let used_distance = used_distance else {
                    print("Failed to fetch usable miles.")
                    return
                }
                DispatchQueue.main.async {
                    self.totalMiles = totalDistance
                    self.usableMiles = totalDistance - used_distance
                }
            }
        }

        // Fetch inventory from Firestore
        FirestoreManager.shared.fetchUserInventory(userId: userId) { [weak self] inventory in
            DispatchQueue.main.async {
                self?.unlockedCars = inventory
            }
        }
    }
    
    func fetchEquippedCar(userId: String) {
        FirestoreManager.shared.fetchEquippedCar(userId: userId) { [weak self] equippedCar in
            DispatchQueue.main.async {
                self?.equippedCar = equippedCar
            }
        }
    }

    func equipCar(userId: String, carName: String) {
        // If carName is empty, it means we're unequipping
        // If not empty, verify the car is unlocked before equipping
        if !carName.isEmpty {
            guard unlockedCars.contains(carName) else { return }
        }
        
        FirestoreManager.shared.equipCar(userId: userId, carName: carName) { [weak self] success, message in
            if success {
                DispatchQueue.main.async {
                    self?.equippedCar = carName
                }
            }
            print(message)
        }
    }

    func unlockCar(userId: String) -> String? {
        let minimum_miles_to_unlock = 1.0
        guard usableMiles >= minimum_miles_to_unlock else { return "Not enough miles to unlock a car!" }

        usableMiles -= minimum_miles_to_unlock
        FirestoreManager.shared.incrementUserDistanceUsed(
            userId: userId,
            distanceUsed: minimum_miles_to_unlock
        ) { error in
            if let error = error {
                print("Failed to update total distance: \(error)")
            }
        }

        var triedRarities = Set<CarRarity>()

        while triedRarities.count < allCarsByRarity.keys.count {
            let rarity = rollForRarity()
            triedRarities.insert(rarity)

            guard let availableCars = allCarsByRarity[rarity]?.filter({ !unlockedCars.contains($0) }),
                  let car = availableCars.randomElement() else {
                print("No cars found for rarity: \(rarity)")
                continue
            }

            unlockedCars.append(car)

            FirestoreManager.shared.addCarToInventory(userId: userId, carName: car) { success, message in
                print(message)
            }

            return "You unlocked \(car)!"
        }

        return "No more cars available to unlock!"
    }

    // Updated to 3-tier system: Common (1-60), Rare (61-89), Legendary (90-100)
    private func rollForRarity() -> CarRarity {
        let randomNumber = Int.random(in: 1...100)
        switch randomNumber {
        case 1...60: return .common
        case 61...89: return .rare
        case 90...100: return .legendary
        default: return .common
        }
    }
}

// MARK: - Car Rarity Enum (Updated to 3-tier system)
enum CarRarity: String, CaseIterable, Hashable {
    case common = "Common"
    case rare = "Rare"
    case legendary = "Legendary"
    
    var color: Color {
        switch self {
        case .common: return .white
        case .rare: return .blue
        case .legendary: return .yellow // Gold color
        }
    }
    
    var name: String {
        return self.rawValue
    }
}
