//
//  ContentView.swift
//  PoseToJsonConverter
//
//  Created by Agung Kurniawan on 12/06/25.
//

import SwiftUI
import PhotosUI

struct ContentView: View {
    @StateObject private var viewModel = PoseConverterViewModel()
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var pickedImage: UIImage?
    @State private var navigateToEditor = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // App title and header
                VStack(spacing: 8) {
                    Text("Pose to JSON Converter")
                        .font(.largeTitle)
                        .bold()
                    
                    Text("Aplikasi untuk konversi pose silat ke format JSON")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Main image placeholder
                Image(systemName: "figure.martial.arts")
                    .font(.system(size: 120))
                    .foregroundColor(.blue)
                    .padding(40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                Spacer()
                
                // Image selection buttons
                VStack(spacing: 16) {
                    PhotoPicker(selectedImage: $pickedImage)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    
                    Button(action: {
                        showingCamera = true
                    }) {
                        Label("Ambil Foto", systemImage: "camera")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                }
                .padding(.horizontal, 40)
                
                // Saved poses access
                if !viewModel.savedPoses.isEmpty {
                    Button(action: {
                        viewModel.showingShareSheet = true
                        viewModel.shareAllPosesAsText()
                    }) {
                        Label("Lihat Semua Pose (\(viewModel.savedPoses.count))", systemImage: "square.stack.3d.up")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .padding(.horizontal, 40)
                }
                
                Spacer()
                
                // Debug info in compact form
                if viewModel.errorMessage != nil || viewModel.isProcessing {
                    VStack {
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                        
                        if viewModel.isProcessing {
                            ProgressView("Mendeteksi pose...")
                                .padding()
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom, 24)
            .navigationDestination(isPresented: $navigateToEditor) {
                EditorView(viewModel: viewModel)
            }
        }
        .onChange(of: pickedImage) { oldImage, newImage in
            print("ContentView: pickedImage changed from \(String(describing: oldImage)) to \(String(describing: newImage))")
            if let image = newImage {
                print("ContentView: Calling processSelectedImage with image size \(image.size)")
                viewModel.processSelectedImage(image)
                navigateToEditor = true
            }
        }
        .sheet(isPresented: $showingCamera) {
            ImagePicker(selectedImage: $pickedImage, sourceType: .camera)
        }
        .sheet(isPresented: $viewModel.showingShareSheet) {
            ShareSheet(text: viewModel.shareText)
        }
        .alert("Success", isPresented: $viewModel.showingExportAlert) {
            Button("OK") { }
        } message: {
            Text(viewModel.exportMessage)
        }
    }
}

struct EditorView: View {
    @ObservedObject var viewModel: PoseConverterViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
            
            // Main content
            VStack(spacing: 0) {
                if viewModel.isProcessing {
                    ProgressView("Mendeteksi pose...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let image = viewModel.selectedImage, viewModel.currentPose != nil {
                    // PoseEditor takes full screen on this view
                    PoseEditorView(viewModel: viewModel, image: image)
                        .background(Color.white)
                } else {
                    // Error state or unexpected state
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Terjadi kesalahan saat memuat pose")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        if let error = viewModel.errorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Bottom controls overlay
            VStack(spacing: 0) {
                // Joint controls
                if viewModel.currentPose != nil {
                    VStack {
                        Divider()
                        ScrollView {
                            VStack(spacing: 16) {
                                // Pose ID section
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Pose ID")
                                        .font(.headline)
                                    
                                    HStack {
                                        TextField("Masukkan ID Pose", text: Binding(
                                            get: { viewModel.currentPose?.poseId ?? "" },
                                            set: { viewModel.updatePoseId($0) }
                                        ))
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        
                                        Button(action: {
                                            viewModel.updatePoseId("jurus1_pose_\(UUID().uuidString.prefix(4))")
                                        }) {
                                            Image(systemName: "arrow.clockwise")
                                        }
                                    }
                                }
                                .padding(.horizontal)
                                
                                Divider()
                                
                                // Selected joint info
                                if let selectedJoint = viewModel.selectedJoint, 
                                   let joint = viewModel.currentPose?.joints[selectedJoint] {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Joint: \(selectedJoint.displayName)")
                                            .font(.headline)
                                        
                                        HStack(spacing: 16) {
                                            Button(action: {
                                                viewModel.toggleJointStatus(joint: selectedJoint, to: .normal)
                                            }) {
                                                Label("Normal", systemImage: "circle.fill")
                                                    .foregroundColor(joint.status == .normal ? .blue : .gray)
                                            }
                                            
                                            Button(action: {
                                                viewModel.toggleJointStatus(joint: selectedJoint, to: .ignored)
                                            }) {
                                                Label("Abaikan", systemImage: "xmark.circle.fill")
                                                    .foregroundColor(joint.status == .ignored ? .gray : .gray.opacity(0.6))
                                            }
                                            
                                            Button(action: {
                                                viewModel.toggleJointStatus(joint: selectedJoint, to: .important)
                                            }) {
                                                Label("Penting", systemImage: "exclamationmark.circle.fill")
                                                    .foregroundColor(joint.status == .important ? .red : .gray.opacity(0.6))
                                            }
                                            
                                            Button(action: {
                                                viewModel.deleteJoint(selectedJoint)
                                            }) {
                                                Label("Hapus", systemImage: "trash")
                                                    .foregroundColor(.red)
                                            }
                                        }
                                    }
                                    .padding(.horizontal)
                                    
                                    Divider()
                                }
                                
                                // Action buttons
                                HStack(spacing: 16) {
                                    Button(action: {
                                        viewModel.savePoseToCollection()
                                    }) {
                                        Label("Simpan", systemImage: "square.and.arrow.down")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: {
                                        viewModel.copyCurrentPoseToClipboard()
                                    }) {
                                        Label("Copy", systemImage: "doc.on.clipboard")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.bordered)
                                    
                                    Button(action: {
                                        viewModel.shareCurrentPoseAsText()
                                    }) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.borderedProminent)
                                }
                                .padding(.horizontal)
                            }
                            .padding(.vertical)
                        }
                        .frame(height: 200)
                        .background(
                            Rectangle()
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -5)
                        )
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(viewModel.currentPose?.poseId ?? "Pose Editor")
                    .font(.headline)
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    viewModel.clearCurrentPose()
                    dismiss()
                }) {
                    Text("Selesai")
                }
            }
        }
    }
}

// Share Sheet untuk berbagi text
struct ShareSheet: UIViewControllerRepresentable {
    let text: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: [text],
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

#Preview {
    ContentView()
}
