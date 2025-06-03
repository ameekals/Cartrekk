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
    
    // Delimiter for car duplicates
    private let duplicateDelimiter = "#"

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
        let baseCarName = getBaseCarName(from: carName)
        for (rarity, cars) in allCarsByRarity {
            if cars.contains(baseCarName) {
                return rarity
            }
        }
        return .common // Default fallback
    }
    
    // Extract base car name without duplicate suffix
    func getBaseCarName(from carName: String) -> String {
        if let delimiterIndex = carName.firstIndex(of: Character(duplicateDelimiter)) {
            return String(carName[..<delimiterIndex])
        }
        return carName
    }
    
    // Get duplicate count for a car
    func getDuplicateCount(for carName: String) -> Int {
        let baseCarName = getBaseCarName(from: carName)
        let duplicates = unlockedCars.filter { getBaseCarName(from: $0) == baseCarName }
        return duplicates.count
    }
    
    // Get unique cars (without duplicates) for display
    func getUniqueUnlockedCars() -> [String] {
        let uniqueBaseNames = Set(unlockedCars.map { getBaseCarName(from: $0) })
        return Array(uniqueBaseNames)
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
            let baseCarName = getBaseCarName(from: carName)
            guard unlockedCars.contains(where: { getBaseCarName(from: $0) == baseCarName }) else { return }
        }
        
        // Store the base car name for equipped car (without duplicate suffix)
        let equippedCarName = carName.isEmpty ? "" : getBaseCarName(from: carName)
        
        FirestoreManager.shared.equipCar(userId: userId, carName: equippedCarName) { [weak self] success, message in
            if success {
                DispatchQueue.main.async {
                    self?.equippedCar = equippedCarName
                }
            }
            print(message)
        }
    }

    func unlockCar(userId: String) -> String? {
        let minimum_miles_to_unlock = 25.0
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

        let rarity = rollForRarity()
        
        guard let availableCars = allCarsByRarity[rarity],
              let selectedBaseCar = availableCars.randomElement() else {
            return "No cars available for rarity: \(rarity)"
        }

        // Check how many duplicates we already have
        let currentDuplicates = unlockedCars.filter { getBaseCarName(from: $0) == selectedBaseCar }
        let duplicateCount = currentDuplicates.count + 1
        
        // Create the car name with duplicate suffix for local storage
        let carWithDuplicateNumber = "\(selectedBaseCar)\(duplicateDelimiter)\(duplicateCount)"
        
        unlockedCars.append(carWithDuplicateNumber)

        // For Firestore, update or add the car with count
        FirestoreManager.shared.addOrUpdateCarInInventory(userId: userId, carName: selectedBaseCar, newCount: duplicateCount) { success, message in
            print(message)
        }

        if duplicateCount > 1 {
            return "You unlocked \(selectedBaseCar) (Copy \(duplicateCount))!"
        } else {
            return "You unlocked \(selectedBaseCar)!"
        }
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
