//
//  C3_PostureApp.swift
//  C3-Posture
//
//  Created by Ahmad Kurniawan Ibrahim on 27/05/25.
//

import SwiftUI

// MARK: - Aplikasi Utama
// Ini adalah entry point (titik masuk) dari aplikasi iOS
// @main menandakan bahwa ini adalah struktur utama yang akan dijalankan pertama kali
@main
struct C3_PostureApp: App {
    // body adalah properti yang mengembalikan Scene (tampilan utama aplikasi)
    var body: some Scene {
        // WindowGroup adalah container untuk menampilkan view utama di dalam window
        WindowGroup {
            // ContentView() adalah tampilan utama yang akan ditampilkan
            ContentView()
        }
    }
}
