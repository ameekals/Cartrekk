//
//  ContentView.swift
//  Cartrekk
//
//  Created by Ameek Singh on 1/18/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Title
                Text("Cartrekk")
                    .font(.largeTitle)
                    .bold()

                // Start Button
                NavigationLink(destination: TimerView()) {
                    Text("Start")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
}

struct TimerView: View {
    @State private var isRecording = false
    @State private var timer: Timer? = nil
    @State private var startTime: Date? = nil
    @State private var elapsedTime: TimeInterval = 0.0
    @State private var timesTraveled: [String] = []
    @State private var distanceTraveled: Double = 0.0 // Distance traveled variable

    var body: some View {
        VStack(spacing: 20) {
            // Timer Display
            Text(formatTimeInterval(elapsedTime))
                .font(.largeTitle)
                .bold()

            // Start/Stop Button
            Button(action: {
                isRecording ? stopRecording() : startRecording()
            }) {
                Text(isRecording ? "End Recording" : "Start Recording")
                    .font(.title2)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(isRecording ? Color.red : Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding(.horizontal)

            // Stats List
            List {
                Section(header: Text("Stats")) {
                    Text("Distance Traveled: \(distanceTraveled, specifier: "%.2f") mi")
                }
                Section(header: Text("Time Traveled")) {
                    ForEach(timesTraveled, id: \.self) { time in
                        Text("Time: \(time)")
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
        }
        .padding()
        .navigationBarTitle("Timer", displayMode: .inline)
    }

    // MARK: - Timer Logic
    private func startRecording() {
        isRecording = true
        startTime = Date()
        elapsedTime = 0.0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if let startTime = startTime {
                elapsedTime = Date().timeIntervalSince(startTime)
            }
        }
    }

    private func stopRecording() {
        isRecording = false
        timer?.invalidate()
        timer = nil
        if let startTime = startTime {
            elapsedTime = Date().timeIntervalSince(startTime)
            timesTraveled.append(formatTimeInterval(elapsedTime))
        }
        elapsedTime = 0.0
        startTime = nil
    }

    // MARK: - Helper Method
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let minutes = Int(interval) / 60
        let seconds = Int(interval) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#Preview {
    ContentView()
}
