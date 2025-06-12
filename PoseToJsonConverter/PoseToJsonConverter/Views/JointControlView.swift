import SwiftUI

struct JointControlView: View {
    @ObservedObject var viewModel: PoseConverterViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Pose ID Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Pose ID")
                    .font(.headline)
                
                HStack {
                    TextField("Masukkan ID Pose", text: Binding(
                        get: { viewModel.currentPose?.poseId ?? "" },
                        set: { viewModel.updatePoseId($0) }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(viewModel.currentPose == nil)
                    
                    Button(action: {
                        viewModel.updatePoseId("jurus1_pose_\(UUID().uuidString.prefix(4))")
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(viewModel.currentPose == nil)
                }
            }
            
            Divider()
            
            // Joint List
            Text("Daftar Joint (\(viewModel.currentPose?.joints.count ?? 0))")
                .font(.headline)
            
            if let pose = viewModel.currentPose {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(JointName.allCases, id: \.self) { jointName in
                            if let joint = pose.joints[jointName] {
                                JointControlRow(
                                    jointName: jointName,
                                    joint: joint,
                                    viewModel: viewModel
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else {
                Text("Tidak ada pose yang terdeteksi")
                    .foregroundColor(.gray)
                    .italic()
            }
            
            Spacer()
            
            // Legend and Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Keterangan:")
                    .font(.caption)
                    .bold()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 16) {
                        Label("Normal", systemImage: "circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        
                        Label("Diabaikan", systemImage: "circle.fill")
                            .foregroundColor(.gray.opacity(0.5))
                            .font(.caption)
                    }
                    
                    HStack(spacing: 16) {
                        Label("Penting", systemImage: "circle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Label("Dapat dihapus", systemImage: "trash")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tips:")
                        .font(.caption)
                        .bold()
                    
                    Text("• Geser titik untuk mengatur posisi")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• Tap & tahan untuk menu opsi")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text("• Hapus joint yang tidak diperlukan")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
}

struct JointControlRow: View {
    let jointName: JointName
    let joint: EditableJoint
    @ObservedObject var viewModel: PoseConverterViewModel
    
    var body: some View {
        HStack {
            // Joint indicator
            Circle()
                .fill(viewModel.colorForJoint(jointName))
                .frame(width: 12, height: 12)
            
            // Joint name
            Text(jointName.displayName)
                .font(.system(size: 14))
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Confidence
            Text("\(Int(joint.confidence * 100))%")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(width: 35)
            
            // Status buttons
            HStack(spacing: 4) {
                Button(action: {
                    viewModel.toggleJointStatus(joint: jointName, to: .normal)
                }) {
                    Image(systemName: "circle.fill")
                        .foregroundColor(joint.status == .normal ? .blue : .gray.opacity(0.3))
                        .font(.system(size: 12))
                }
                
                Button(action: {
                    viewModel.toggleJointStatus(joint: jointName, to: .ignored)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(joint.status == .ignored ? .gray : .gray.opacity(0.3))
                        .font(.system(size: 12))
                }
                
                Button(action: {
                    viewModel.toggleJointStatus(joint: jointName, to: .important)
                }) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(joint.status == .important ? .red : .gray.opacity(0.3))
                        .font(.system(size: 12))
                }
                
                // Delete button
                Button(action: {
                    viewModel.deleteJoint(jointName)
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(viewModel.selectedJoint == jointName ? Color.blue.opacity(0.1) : Color.clear)
        )
        .onTapGesture {
            viewModel.selectedJoint = jointName
        }
    }
} 