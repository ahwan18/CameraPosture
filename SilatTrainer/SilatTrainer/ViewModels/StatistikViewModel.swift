import Foundation
import SwiftUI
import SwiftData

class StatistikViewModel: ObservableObject {
    @Published var weeklyPoseData: [String: Int] = [:]
    @Published var monthlyPoseData: [String: Int] = [:]
    @Published var totalSessions: Int = 0
    @Published var averageDuration: Int = 0
    @Published var progressPercentage: Int = 0
    @Published var selectedJurus: String = "Jurus 1"
    
    private let calendar = Calendar.current
    
    func loadStatistics(forViewMode viewMode: StatistikView.ViewMode, using modelContext: ModelContext) {
        // Load sessions from SwiftData
        let jurusToSearch = selectedJurus // Capture selected jurus in a local variable
        
        let predicate = #Predicate<TrainingSession> { session in
            session.jurus == jurusToSearch
        }
        
        let descriptor = FetchDescriptor<TrainingSession>(predicate: predicate)
        
        do {
            let sessions = try modelContext.fetch(descriptor)
            
            // Filter sessions based on time period
            let filteredSessions = filterSessions(sessions, forViewMode: viewMode)
            
            // Calculate statistics
            calculatePoseSuccess(from: filteredSessions, forViewMode: viewMode)
            calculateSessionStats(from: filteredSessions)
            calculateProgress(from: filteredSessions)
        } catch {
            print("Error fetching sessions: \(error)")
            // Provide sample data if fetching fails
            provideDefaultData()
        }
    }
    
    private func filterSessions(_ sessions: [TrainingSession], forViewMode viewMode: StatistikView.ViewMode) -> [TrainingSession] {
        let now = Date()
        
        return sessions.filter { session in
            switch viewMode {
            case .minggu:
                // Filter sessions from the last 7 days
                let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
                return session.date >= weekAgo
            case .bulan:
                // Filter sessions from the last 30 days
                let monthAgo = calendar.date(byAdding: .day, value: -30, to: now)!
                return session.date >= monthAgo
            }
        }
    }
    
    private func calculatePoseSuccess(from sessions: [TrainingSession], forViewMode viewMode: StatistikView.ViewMode) {
        var poseSuccessCount = Array(repeating: 0, count: 7)
        
        // Process each session
        for session in sessions {
            // Group pose results by pose number
            for result in session.poseResults {
                if result.poseNumber >= 1 && result.poseNumber <= 7 {
                    let index = result.poseNumber - 1
                    
                    // Count only successful poses
                    if result.isCorrect {
                        poseSuccessCount[index] += 1
                    }
                }
            }
        }
        
        // Map success counts to dictionary
        var poseSuccessData: [String: Int] = [:]
        
        for i in 0..<7 {
            let successes = poseSuccessCount[i]
            poseSuccessData["A\(i+1)"] = successes
        }
        
        // Update the published property based on selected view mode
        DispatchQueue.main.async {
            if poseSuccessData.isEmpty {
                // Use default sample data if no real data exists
                self.provideDefaultData()
            } else {
                // Use actual data
                switch viewMode {
                case .minggu:
                    self.weeklyPoseData = poseSuccessData
                case .bulan:
                    self.monthlyPoseData = poseSuccessData
                }
            }
        }
    }
    
    private func calculateSessionStats(from sessions: [TrainingSession]) {
        // Calculate total sessions
        let sessionsCount = sessions.count
        
        // Calculate average duration
        let totalDuration = sessions.reduce(0) { $0 + $1.duration }
        let avgDuration = sessions.isEmpty ? 0 : totalDuration / sessionsCount
        
        // Update published properties
        DispatchQueue.main.async {
            self.totalSessions = sessionsCount
            self.averageDuration = avgDuration
        }
    }
    
    private func calculateProgress(from sessions: [TrainingSession]) {
        // Calculate overall progress percentage based on all poses
        let totalPoseResults = sessions.flatMap { $0.poseResults }
        let totalSuccessful = totalPoseResults.filter { $0.isCorrect }.count
        
        let progress = totalPoseResults.isEmpty ? 0 : 
            Int((Double(totalSuccessful) / Double(totalPoseResults.count)) * 100)
        
        DispatchQueue.main.async {
            self.progressPercentage = progress
        }
    }
    
    private func provideDefaultData() {
        DispatchQueue.main.async {
            self.monthlyPoseData = [
                "A1": 0,
                "A2": 0,
                "A3": 0,
                "A4": 0,
                "A5": 0,
                "A6": 0,
                "A7": 0
            ]
            self.weeklyPoseData = [
                "A1": 0,
                "A2": 0,
                "A3": 0,
                "A4": 0,
                "A5": 0,
                "A6": 0,
                "A7": 0
            ]
            self.totalSessions = 0
            self.averageDuration = 0
            self.progressPercentage = 0
        }
    }
    
    func resetAllData(using modelContext: ModelContext) {
        do {
            // Fetch all training sessions
            let descriptor = FetchDescriptor<TrainingSession>()
            let allSessions = try modelContext.fetch(descriptor)
            
            // Delete all sessions
            for session in allSessions {
                modelContext.delete(session)
            }
            
            // Save changes
            try modelContext.save()
            
            // Reset UI data
            provideDefaultData()
        } catch {
            print("Error resetting data: \(error)")
        }
    }
} 