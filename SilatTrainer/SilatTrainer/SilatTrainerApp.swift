//
//  SilatTrainerApp.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 12/06/25.
//

import SwiftUI

@main
struct SilatTrainerApp: App {
    @State private var path = NavigationPath()

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $path) {
                HomeView(navigate: { route in
                    path.append(route)
                })
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .latihan:
                        LatihanView(
                            navigate: { path.append($0) },
                            close: {
                                path = NavigationPath()
                            }
                        )
                    case .tutorial:
                        TutorialView(navigate: { path.append($0) })
                    case .bukuJurus:
                        BukuJurusIpsi()
                    case .caraMenggunakan:
                        CaraMenggunakan()
                    case .finish:
                        FinishView(navigate: { path.append($0) })
                    case .rekap:
                        RekapLatihanView(resetToHome: {
                            path = NavigationPath()
                        })
                    }
                }
            }
        }
    }
}

