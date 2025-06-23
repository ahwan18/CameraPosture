//
//  BukuJurusIpsi.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//

import SwiftUI

struct BukuJurusIpsi: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color("BackgroundTutorial")
            
            Button(action: {
                dismiss()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Kembali")
                        .font(.title3)
                    Spacer()
                }
                .foregroundColor(.yellow)
                .padding(.leading, 20)
                .padding(.top, 70)
            }
            
            VStack {
                Spacer()
                HStack {
                    Text("Kitab Jurus Tunggal Baku IPSI")
                        .font(.headline)
                        .padding(.bottom, 10)
                        .foregroundStyle(.white)
                    Spacer()
                }
                if let url = Bundle.main.url(forResource: "BukuPanduanJurusTunggalBakuIPSI", withExtension: "pdf") {
                    PDFViewer(url: url)
                        .frame(height: 450)
                        .cornerRadius(10)
                } else {
                    Text("PDF not found.")
                        .foregroundColor(.red)
                }
                Spacer()
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 100)
        }
        .ignoresSafeArea()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationBarBackButtonHidden(true)
    }
}


#Preview {
    BukuJurusIpsi()
}
