//
//  ContentView.swift
//  C3-Posture
//
//  Created by Ahmad Kurniawan Ibrahim on 27/05/25.
//

import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    
    // MARK: - ViewModels
    
    @StateObject private var mainViewModel = MainViewModel()
    
    // MARK: - State
    
    @State private var showingSequentialTraining = false
    
    var body: some View {
        ZStack {
            // Home View - only sequential training now
            homeView
        }
        .fullScreenCover(isPresented: $showingSequentialTraining) {
            SequentialPoseView()
        }
        .alert("Error", isPresented: $mainViewModel.showError) {
            Button("OK") {
                mainViewModel.clearError()
            }
        } message: {
            if let errorMessage = mainViewModel.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Home View
    
    private var homeView: some View {
        GeometryReader { geometry in
            ZStack {
                // Gradient background
                LinearGradient(
                    gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.blue.opacity(0.9)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 40) {
                    Spacer()
                    
                    // App Title with animation
                    VStack(spacing: 10) {
                        Image(systemName: "figure.strengthtraining.functional")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Text("Posture Master")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
                        
                        Text("Sequential Yoga Training")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Start Training Button
                    Button(action: {
                        withAnimation(.spring()) {
                            showingSequentialTraining = true
                        }
                    }) {
                        HStack(spacing: 15) {
                            Image(systemName: "play.fill")
                                .font(.title2)
                            
                            Text("Start Training")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.orange, Color.red]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        )
                        .scaleEffect(mainViewModel.isLoading ? 0.95 : 1.0)
                        .animation(.easeInOut(duration: 0.1), value: mainViewModel.isLoading)
                    }
                    .disabled(mainViewModel.isLoading)
                    
                    // Features list
                    VStack(spacing: 15) {
                        FeatureRow(icon: "camera.fill", text: "3-meter optimal distance")
                        FeatureRow(icon: "target", text: "Full body pose detection")
                        FeatureRow(icon: "timer", text: "3-second hold requirement")
                        FeatureRow(icon: "arrow.triangle.2.circlepath", text: "Auto-reset positioning")
                    }
                    .padding(.horizontal, 30)
                    
                    Spacer()
                    
                    if mainViewModel.isLoading {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Preparing...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
        }
    }
    

}

// MARK: - Feature Row Component

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 24, height: 24)
            
            Text(text)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.white.opacity(0.15))
        )
    }
}



// Preview for SwiftUI Canvas
#Preview {
    ContentView()
}
