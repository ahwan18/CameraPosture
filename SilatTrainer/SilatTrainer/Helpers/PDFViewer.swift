//
//  PDFViewer.swift
//  SilatTrainer
//
//  Created by Agung Kurniawan on 14/06/25.
//
import SwiftUI
import PDFKit

struct PDFViewer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = PDFDocument(url: url)
    }
}
