//
//  HomeView.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//


import SwiftUI

struct HomeView: View {
    var navigate: (AppRoute) -> Void
    
    var body: some View {
        TabView {
            ZStack {
                // Background with character - stretch to fill entire screen
                Image("bg1")
                    .resizable()
                    .frame(maxHeight: .infinity)
                    .scaleEffect(1.02)
                    .offset(y: 0)
                    .ignoresSafeArea()
                
                Image("person")
                    .resizable()
                    .frame(width: 450, height: 450)
                    .padding()
                    .position(x: 200, y: 440)
                
                // Content overlay
                VStack(spacing: 0) {
                    // Top section with info button
                    HStack {
                        Spacer()
                        Button(action: {
                            // Action for info button
                            navigate(.tutorial)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.yellow)
                                    .frame(width: 30, height: 30)
                                
                                Image(systemName: "info")
                                    .font(.title2)
                                    .foregroundColor(.black)
                            }
                        }
                        .padding(.bottom, 20)
                        .padding(.top, 20)
                        .padding(.trailing, 35)
                    }
                    
                    
                    
                    // Title Section
                    VStack(spacing: 5) {
                        Text("SIRAJ")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Latih Jurus Tunggal")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text("Baku IPSI-mu")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    // Start Button
                    Button(action: {
                        navigate(.latihan)
                    }) {
                        Text("Mulai Latihan")
                            .font(.title2)
                            .foregroundColor(.black)
                            .fontWeight(.medium)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .cornerRadius(20)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 50)
                    
                    //                // Tab Bar
                    //                HStack {
                    //                    Spacer()
                    //
                    //                    // Latihan Tab
                    //                    Button(action: {
                    //                        navigate(.latihan)
                    //                    }) {
                    //                        VStack {
                    //                            Image(systemName: "figure.martial.arts")
                    //                                .resizable()
                    //                                .scaledToFit()
                    //                                .frame(width: 30, height: 30)
                    //
                    //                            Text("Latihan")
                    //                                .font(.caption)
                    //                        }
                    //                        .foregroundColor(.yellow)
                    //                        .frame(maxWidth: .infinity)
                    //                    }
                    //
                    //                    Spacer()
                    //
                    //                    // Ringkasan Tab
                    //                    Button(action: {
                    //                        navigate(.statistik)
                    //                    }) {
                    //                        VStack {
                    //                            Image(systemName: "star")
                    //                                .resizable()
                    //                                .scaledToFit()
                    //                                .frame(width: 30, height: 30)
                    //
                    //                            Text("Ringkasan")
                    //                                .font(.caption)
                    //                        }
                    //                        .foregroundColor(.gray)
                    //                        .frame(maxWidth: .infinity)
                    //                    }
                    //
                    //                    Spacer()
                    //                }
                    //                .padding(.vertical, 10)
                    //                .background(Color.black)
                }
            }
            .tabItem {
                Label("Latihan", systemImage: "figure.martial.arts")
            }
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(.black, for: .tabBar)
            
            StatistikView()
                .tabItem {
                    Label("Ringkasan", systemImage: "star")
                }
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarBackground(.black, for: .tabBar)
        }
        .accentColor(.yellow)
    }
}

#Preview {
    HomeView(navigate: { _ in })
}
