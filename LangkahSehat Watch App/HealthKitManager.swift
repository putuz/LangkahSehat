//
//  HealthKitManager.swift
//  LangkahSehat Watch App
//
//  Created by Putut Yusri Bahtiar on 01/07/24.
//

import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var stepData: [StepsModel] = []
    @Published var todayData = StepsModel(date: Date(), stepsCount: 0.0, xp: 0, level: 1, xpForNextLevel: 100, activeEnergyBurned: 0.0)
    @Published var todayHeartRate = HeartRateModel(date: Date(), heartRate: 0.0)
    
    let stepsPerXP = 100  // Define how many steps are equivalent to 1 XP
    var cumulativeXP: Int = 0  // Store cumulative XP
    
    init() {
        requestAuthorization()
    }
    
    func requestAuthorization() {
        let readTypes = Set([
            HKObjectType.quantityType(forIdentifier: .stepCount)!, 
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ])
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if success {
                self.startObservingSteps()
                self.startObservingActiveEnergyBurned()
                self.startObservingHeartRate()
            } else {
                print("Authorization failed: \(String(describing: error?.localizedDescription))")
            }
        }
    }
    
    func startObservingHeartRate() {
        let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate)!
        
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            if error == nil {
                self?.fetchLatestHeartRate()
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchLatestHeartRate() {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: heartRateType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, results, error in
            if let error = error {
                print("Error fetching heart rate: \(error.localizedDescription)")
                return
            }
            
            guard let self = self, let results = results as? [HKQuantitySample], let sample = results.first else {
                print("No heart rate samples found")
                return
            }
            
            let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            
            DispatchQueue.main.async {
                self.todayHeartRate = HeartRateModel(date: sample.endDate, heartRate: heartRate)
            }
        }
        
        healthStore.execute(query)
    }
    
    
    func getSteps(for period: DateComponents, completion: @escaping (StepsModel) -> Void) {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: period, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            var steps = 0.0
            
            if let result = result, let sum = result.sumQuantity() {
                steps = sum.doubleValue(for: HKUnit.count())
            }
            
            DispatchQueue.main.async {
                completion(StepsModel(date: endDate, stepsCount: steps, xp: Int(steps) / self.stepsPerXP, level: 1, xpForNextLevel: 100, activeEnergyBurned: 0.0))
            }
        }
        
        healthStore.execute(query)
    }
    
    func getActiveEnergyBurned(for period: DateComponents, completion: @escaping (Double) -> Void) {
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let endDate = Date()
        let startDate = Calendar.current.date(byAdding: period, to: endDate)!
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
            var energyBurned = 0.0
            
            if let result = result, let sum = result.sumQuantity() {
                energyBurned = sum.doubleValue(for: HKUnit.kilocalorie())
            }
            
            DispatchQueue.main.async {
                completion(energyBurned)
            }
        }
        
        healthStore.execute(query)
    }
    
    func fetchDataForAllPeriods() {
        getSteps(for: DateComponents(day: -1)) { [weak self] todaySteps in
            self?.todayData = todaySteps
            self?.getActiveEnergyBurned(for: DateComponents(day: -1)) { todayEnergy in
                self?.todayData.activeEnergyBurned = todayEnergy
                self?.updateXPAndLevel(for: &self!.todayData)
                self?.stepData.append(self!.todayData)
            }
        }
        
        getSteps(for: DateComponents(day: -7)) { [weak self] weekSteps in
            var weekData = weekSteps
            self?.getActiveEnergyBurned(for: DateComponents(day: -7)) { weekEnergy in
                weekData.activeEnergyBurned = weekEnergy
                self?.updateXPAndLevel(for: &weekData)
                self?.stepData.append(weekData)
            }
        }
        
        getSteps(for: DateComponents(month: -1)) { [weak self] monthSteps in
            var monthData = monthSteps
            self?.getActiveEnergyBurned(for: DateComponents(month: -1)) { monthEnergy in
                monthData.activeEnergyBurned = monthEnergy
                self?.updateXPAndLevel(for: &monthData)
                self?.stepData.append(monthData)
            }
        }
    }
    
    func startObservingSteps() {
        let stepType = HKObjectType.quantityType(forIdentifier: .stepCount)!
        
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            if error == nil {
                self?.fetchDataForAllPeriods()
            }
        }
        
        healthStore.execute(query)
    }
    
    func startObservingActiveEnergyBurned() {
        let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        let query = HKObserverQuery(sampleType: energyType, predicate: nil) { [weak self] _, _, error in
            if error == nil {
                self?.fetchDataForAllPeriods()
            }
        }
        
        healthStore.execute(query)
    }
    
    func updateXPAndLevel(for model: inout StepsModel) {
        model.xp = Int(model.stepsCount) / stepsPerXP
        let newLevel = calculateLevel(from: model.xp)
        
        if newLevel > model.level {
            model.level = newLevel
            model.xpForNextLevel = calculateXPForNextLevel(level: model.level)
        }
    }
    
    func calculateLevel(from xp: Int) -> Int {
        var level = 1
        var xpForNextLevel = 100
        
        while xp >= xpForNextLevel {
            level += 1
            xpForNextLevel += calculateXPForNextLevel(level: level)
        }
        
        return level
    }
    
    func calculateXPForNextLevel(level: Int) -> Int {
        // Quadratic formula for XP required to reach next level
        return 100 + 50 * (level - 1) * (level - 1)
    }
    
    func getCurrentData(for period: Period) -> StepsModel {
        switch period {
        case .today:
            return todayData
        case .week:
            return stepData.first(where: { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }) ?? StepsModel(date: Date(), stepsCount: 0, xp: 0, level: 1, xpForNextLevel: 100, activeEnergyBurned: 0.0)
        case .month:
            return stepData.first(where: { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }) ?? StepsModel(date: Date(), stepsCount: 0, xp: 0, level: 1, xpForNextLevel: 100, activeEnergyBurned: 0.0)
        }
    }
}


enum Period: String, CaseIterable, Identifiable {
    case today = "Today"
    case week = "Week"
    case month = "Month"
    
    var id: String { self.rawValue }
}
