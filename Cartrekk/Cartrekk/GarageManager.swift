//
//  GarageManager.swift
//  Cartrekk
//
//  Created by Ameek Singh on 2/17/25.
//

import FirebaseFirestore
import FirebaseAuth

class GarageManager: ObservableObject {
    static let shared = GarageManager()

    @Published var totalMiles: Double = 0.0
    @Published var usableMiles: Double = 0.0
    @Published var unlockedCars: [String] = []

    private let allCarsByRarity: [LootboxTier: [String]] = [
        .rare: ["redpink_truck"],
        .epic: ["yellow_car_stripe"],
        .legendary: ["blue_car_hat"]
    ]

    private init() {
        if let userId = Auth.auth().currentUser?.uid {
            fetchTotalMiles(userId: userId)
        } else {
            print("No logged-in user. Cannot fetch total miles.")
        }
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

        let rarity = rollForRarity()
        guard let availableCars = allCarsByRarity[rarity], let car = availableCars.randomElement() else {
            print("No cars found for rarity: \(rarity)")
            return "Failed to unlock a car!"
        }

        if unlockedCars.contains(car) {
            return "You've already unlocked \(car)!"
        }

        unlockedCars.append(car)

        // Persist in Firestore
        FirestoreManager.shared.addCarToInventory(userId: userId, carName: car) { success, message in
            print(message)
        }

        return "You unlocked \(car)!"
    }

    private func rollForRarity() -> LootboxTier {
        let randomNumber = Int.random(in: 1...100)
        switch randomNumber {
        case 1...50: return .common
        case 51...75: return .uncommon
        case 76...91: return .rare
        case 92...98: return .epic
        case 99...100: return .legendary
        default: return .common
        }
    }
}

// MARK: - Lootbox Rarity Enum
enum LootboxTier: String {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
}
