import SwiftUI

struct PoseEditorView: View {
    @ObservedObject var viewModel: PoseConverterViewModel
    let image: UIImage
    @State private var imageSize: CGSize = .zero
    @State private var showingDeleteAlert = false
    @State private var jointToDelete: JointName?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .background(
                        GeometryReader { imageGeometry in
                            Color.clear
                                .onAppear {
                                    imageSize = imageGeometry.size
                                }
                                .onChange(of: imageGeometry.size) { oldSize, newSize in
                                    imageSize = newSize
                                }
                        }
                    )
                
                // Joint overlay
                if let pose = viewModel.currentPose {
                    ForEach(Array(pose.joints.keys), id: \.self) { jointName in
                        if let joint = pose.joints[jointName] {
                            EditableJointView(
                                jointName: jointName,
                                joint: joint,
                                imageSize: imageSize,
                                viewModel: viewModel,
                                onDelete: {
                                    jointToDelete = jointName
                                    showingDeleteAlert = true
                                }
                            )
                        }
                    }
                }
                
                // Instructions overlay
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Geser titik untuk mengatur posisi", systemImage: "hand.point.up.left")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                            
                            Label("Tap & tahan untuk menu opsi", systemImage: "hand.tap")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        Spacer()
                    }
                    Spacer()
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
        }
        .alert("Hapus Joint", isPresented: $showingDeleteAlert) {
            Button("Batal", role: .cancel) { }
            Button("Hapus", role: .destructive) {
                if let joint = jointToDelete {
                    viewModel.deleteJoint(joint)
                }
            }
        } message: {
            if let joint = jointToDelete {
                Text("Hapus joint \(joint.displayName)?")
            }
        }
    }
}

struct EditableJointView: View {
    let jointName: JointName
    let joint: EditableJoint
    let imageSize: CGSize
    @ObservedObject var viewModel: PoseConverterViewModel
    let onDelete: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var showingLabel = false
    
    // Convert normalized position to view position
    var viewPosition: CGPoint {
        CGPoint(
            x: joint.normalizedPosition.x * imageSize.width,
            y: joint.normalizedPosition.y * imageSize.height
        )
    }
    
    var jointColor: Color {
        switch joint.status {
        case .normal:
            return .blue
        case .ignored:
            return .gray.opacity(0.5)
        case .important:
            return .red
        }
    }
    
    var body: some View {
        ZStack {
            // Joint circle with glow effect
            Circle()
                .fill(jointColor)
                .frame(width: isDragging ? 28 : 20, height: isDragging ? 28 : 20)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
                .shadow(color: jointColor.opacity(0.5), radius: isDragging ? 8 : 4)
                .scaleEffect(viewModel.selectedJoint == jointName ? 1.3 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .animation(.easeInOut(duration: 0.2), value: viewModel.selectedJoint == jointName)
            
            // Joint label
            if showingLabel || viewModel.selectedJoint == jointName {
                VStack {
                    Text(jointName.displayName)
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    Spacer()
                        .frame(height: 25)
                }
            }
        }
        .position(viewPosition)
        .offset(dragOffset)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if !isDragging {
                        isDragging = true
                        viewModel.selectedJoint = jointName
                        showingLabel = true
                    }
                    dragOffset = value.translation
                }
                .onEnded { value in
                    // Calculate new normalized position
                    let newViewPosition = CGPoint(
                        x: viewPosition.x + value.translation.width,
                        y: viewPosition.y + value.translation.height
                    )
                    
                    let newNormalizedPosition = CGPoint(
                        x: newViewPosition.x / imageSize.width,
                        y: newViewPosition.y / imageSize.height
                    )
                    
                    // Clamp to 0-1 range
                    let clampedPosition = CGPoint(
                        x: min(max(newNormalizedPosition.x, 0), 1),
                        y: min(max(newNormalizedPosition.y, 0), 1)
                    )
                    
                    viewModel.updateJointPosition(joint: jointName, to: clampedPosition)
                    
                    dragOffset = .zero
                    isDragging = false
                    
                    // Hide label after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if viewModel.selectedJoint != jointName {
                            showingLabel = false
                        }
                    }
                }
        )
        .onTapGesture {
            viewModel.selectedJoint = jointName
            showingLabel = true
            
            // Hide label after delay if not selected
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if viewModel.selectedJoint != jointName {
                    showingLabel = false
                }
            }
        }
        .contextMenu {
            Button(action: {
                viewModel.toggleJointStatus(joint: jointName, to: .normal)
            }) {
                Label("Normal", systemImage: "circle.fill")
            }
            
            Button(action: {
                viewModel.toggleJointStatus(joint: jointName, to: .ignored)
            }) {
                Label("Abaikan", systemImage: "xmark.circle.fill")
            }
            
            Button(action: {
                viewModel.toggleJointStatus(joint: jointName, to: .important)
            }) {
                Label("Penting", systemImage: "exclamationmark.circle.fill")
            }
            
            Divider()
            
            Button(action: onDelete) {
                Label("Hapus Joint", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
    }
} 