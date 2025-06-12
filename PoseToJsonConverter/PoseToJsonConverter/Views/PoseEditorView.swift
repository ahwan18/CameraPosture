import SwiftUI

struct PoseEditorView: View {
    @ObservedObject var viewModel: PoseConverterViewModel
    let image: UIImage
    @State private var imageSize: CGSize = .zero
    @State private var showingDeleteAlert = false
    @State private var jointToDelete: JointName?
    
    // Fungsi untuk menghitung ukuran dan offset gambar yang di-fit ke frame
    func fittedImageInfo(containerSize: CGSize, imageSize: CGSize) -> (drawnSize: CGSize, offset: CGPoint) {
        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height
        var drawnSize = CGSize.zero
        var offset = CGPoint.zero
        if imageAspect > containerAspect {
            // Gambar lebih lebar dari container
            drawnSize.width = containerSize.width
            drawnSize.height = containerSize.width / imageAspect
            offset.x = 0
            offset.y = (containerSize.height - drawnSize.height) / 2
        } else {
            // Gambar lebih tinggi dari container
            drawnSize.height = containerSize.height
            drawnSize.width = containerSize.height * imageAspect
            offset.x = (containerSize.width - drawnSize.width) / 2
            offset.y = 0
        }
        return (drawnSize, offset)
    }
    
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
                
                // Joint connections
                if let pose = viewModel.currentPose {
                    let info = fittedImageInfo(containerSize: geometry.size, imageSize: image.size)
                    ForEach(JointConnection.defaultConnections) { connection in
                        if let fromJoint = pose.joints[connection.from],
                           let toJoint = pose.joints[connection.to] {
                            JointConnectionView(
                                connection: connection,
                                fromJoint: fromJoint,
                                toJoint: toJoint,
                                imageSize: info.drawnSize,
                                offset: info.offset
                            )
                        }
                    }
                }
                
                // Joint overlay
                if let pose = viewModel.currentPose {
                    let info = fittedImageInfo(containerSize: geometry.size, imageSize: image.size)
                    ForEach(Array(pose.joints.keys), id: \.self) { jointName in
                        if let joint = pose.joints[jointName],
                           !JointConnection.shouldIgnoreJoint(jointName) {
                            EditableJointView(
                                jointName: jointName,
                                joint: joint,
                                imageSize: info.drawnSize,
                                offset: info.offset,
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
    let offset: CGPoint
    @ObservedObject var viewModel: PoseConverterViewModel
    let onDelete: () -> Void
    
    @State private var dragOffset = CGSize.zero
    @State private var isDragging = false
    @State private var showingLabel = false
    
    // Convert normalized position to view position
    var viewPosition: CGPoint {
        CGPoint(
            x: joint.normalizedPosition.x * imageSize.width + offset.x,
            y: joint.normalizedPosition.y * imageSize.height + offset.y
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
                        x: viewPosition.x + value.translation.width - offset.x,
                        y: viewPosition.y + value.translation.height - offset.y
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

struct JointConnectionView: View {
    let connection: JointConnection
    let fromJoint: EditableJoint
    let toJoint: EditableJoint
    let imageSize: CGSize
    let offset: CGPoint
    
    var fromPosition: CGPoint {
        CGPoint(
            x: fromJoint.normalizedPosition.x * imageSize.width + offset.x,
            y: fromJoint.normalizedPosition.y * imageSize.height + offset.y
        )
    }
    
    var toPosition: CGPoint {
        CGPoint(
            x: toJoint.normalizedPosition.x * imageSize.width + offset.x,
            y: toJoint.normalizedPosition.y * imageSize.height + offset.y
        )
    }
    
    var body: some View {
        Path { path in
            path.move(to: fromPosition)
            path.addLine(to: toPosition)
        }
        .stroke(
            LinearGradient(
                colors: [
                    jointColor(fromJoint.status),
                    jointColor(toJoint.status)
                ],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(
                lineWidth: 2,
                lineCap: .round,
                lineJoin: .round
            )
        )
    }
    
    private func jointColor(_ status: JointStatus) -> Color {
        switch status {
        case .normal:
            return .blue
        case .ignored:
            return .gray.opacity(0.5)
        case .important:
            return .red
        }
    }
} 
