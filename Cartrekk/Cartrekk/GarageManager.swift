//
//  GarageManager.swift
//  Cartrekk
//
//  Created by Ameek Singh on 2/17/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class GarageManager: ObservableObject {
    static let shared = GarageManager() // Singleton instance

    // Can input test values for now
    @Published var totalMiles: Double = 0.0
    @Published var usableMiles: Double = 0.0
    @Published var unlockedCars: [String] = [] // Unlocked cars

    private let allCarsByRarity: [LootboxTier: [String]] = [
        .common: ["car1"],
        .uncommon: ["car2"],
        .rare: ["car3"],
        .epic: ["car4"],
        .legendary: ["car5"]
    ]

    private init() {
    }
    
    func addMiles(_ miles: Double) {
        totalMiles += miles
        usableMiles += miles
    }

    func unlockCar() -> String? {
        guard usableMiles >= 100 else { return nil } // Not enough points

        usableMiles -= 100 // Deduct points
        let rarity = rollForRarity() // Determine rarity
        guard let availableCars = allCarsByRarity[rarity], let car = availableCars.randomElement() else { return nil }

        unlockedCars.append(car) // Add the car to unlocked list
        return car
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

enum LootboxTier: String {
    case common = "Common"
    case uncommon = "Uncommon"
    case rare = "Rare"
    case epic = "Epic"
    case legendary = "Legendary"
}
