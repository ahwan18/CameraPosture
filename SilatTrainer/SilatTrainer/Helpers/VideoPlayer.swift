//
//  VideoPlayer.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//

import SwiftUI
import AVKit

struct VideoPlayerView: View {
    let url: URL

    var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .onDisappear {
                // Stop the video when the view disappears
                AVPlayer(url: url).pause()
            }
            .cornerRadius(12)
    }
}

