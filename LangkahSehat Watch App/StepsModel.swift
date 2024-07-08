//
//  StepsModel.swift
//  LangkahSehat Watch App
//
//  Created by Putut Yusri Bahtiar on 04/07/24.
//

import Foundation

struct StepsModel {
    var date: Date
    var stepsCount: Double
    var xp: Int
    var level: Int
    var xpForNextLevel: Int
    var activeEnergyBurned: Double
}

struct HeartRateModel {
    var date: Date
    var heartRate: Double
}
