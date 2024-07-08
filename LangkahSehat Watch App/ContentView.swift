//
//  ContentView.swift
//  LangkahSehat Watch App
//
//  Created by Putut Yusri Bahtiar on 01/07/24.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject private var healthKitManager = HealthKitManager()
    @State private var showingAlert = false
    @State private var selectedPeriod: Period = .today
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Period", selection: $selectedPeriod) {
                ForEach(Period.allCases) { period in
                    Text(period.rawValue).tag(period)
                        .font(.footnote)
                }
            }
            .pickerStyle(WheelPickerStyle())
            .frame(height: 50)
            
            let currentData = healthKitManager.getCurrentData(for: selectedPeriod)
            
            HStack {
                Image(systemName: "figure.step.training")
                    .foregroundStyle(.green)
                Text("Steps \(selectedPeriod.rawValue): \(Int(currentData.stepsCount))")
            }
            .font(.caption)
            
            HStack {
                Image(systemName: "flame")
                    .foregroundStyle(.pink)
                Text("Calories : \(Int(currentData.activeEnergyBurned))")
            }
            .font(.caption)
            
            HStack {
                Image(systemName: "star.circle.fill")
                    .foregroundStyle(.yellow)
                Text("XP: \(currentData.xp) / \(currentData.xpForNextLevel)")
                
                Image(systemName: "info.circle.fill")
                    .onTapGesture {
                        showingAlert = true
                    }
                    .alert(isPresented: $showingAlert) {
                        Alert(title: Text("Important message"), message: Text("100 Step = 1XP"), dismissButton: .default(Text("Got it!")))
                    }
            }
            .font(.caption)
            
            HStack {
                Image(systemName: "crown")
                    .foregroundStyle(.blue)
                Text("Level: \(currentData.level)")
            }
            .font(.caption)
            
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .scaleEffect(1.0 + CGFloat(sin(Date().timeIntervalSince1970 * Double(healthKitManager.todayHeartRate.heartRate) / 60.0)) * 0.1)
                    .animation(.easeInOut(duration: 60.0 / Double(healthKitManager.todayHeartRate.heartRate)).repeatForever(autoreverses: true), value: healthKitManager.todayHeartRate.heartRate)
                Text("Heart Rate: \(Int(healthKitManager.todayHeartRate.heartRate)) BPM")
            }
            .font(.caption)
        }
        .padding()
        .onAppear {
            healthKitManager.fetchDataForAllPeriods()
            healthKitManager.startObservingHeartRate()
        }
    }
}


#Preview {
    ContentView()
}
