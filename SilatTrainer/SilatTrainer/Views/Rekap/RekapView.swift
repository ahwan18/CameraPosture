import SwiftUI

struct RekapLatihanView: View {
    var resetToHome: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise = 0
    
    // Ambil data dari TrainingResultService
    private let trainingResult: TrainingResult? = TrainingResultService.shared.lastTrainingResult
    
    // Computed properties based on training result
    private var duration: Int {
        return trainingResult?.duration ?? 0
    }
    
    private var totalPoses: Int {
        return trainingResult?.totalPoses ?? 7
    }
    
    private var correctPoses: Int {
        return trainingResult?.correctPoses ?? 0
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Bagian Header
            
            VStack {
                HStack {
                    Text("Ringkasan Jurus 1")
                        .foregroundStyle(.white)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.leading, 25)
                        .padding(.top)
                    
                    Spacer()
                }
                
                HStack(spacing: 25) {
                    // Durasi exercise card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Durasi")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)

                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(duration)") // Menggunakan data durasi dari hasil training
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("Detik")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.bottom, 6)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading) // atur posisi seluruh VStack ke kiri
                    .frame(height: 75)
                    .background(Color(red: 96/255, green: 54/255, blue: 54/255)) // warna coklat seperti gambar
                    .cornerRadius(8)

                    // Presisi exercise card
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Presisi")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)

                        HStack(alignment: .bottom, spacing: 4) {
                            Text("\(correctPoses)/\(totalPoses)") // Menggunakan data presisi dari hasil training
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)

                            Text("Gerakan")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.bottom, 6)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading) // atur posisi seluruh VStack ke kiri
                    .frame(height: 75)
                    .background(Color(red: 96/255, green: 54/255, blue: 54/255)) // warna coklat seperti gambar
                    .cornerRadius(8)

                }
                .padding(.horizontal, 25)
            }
            .padding(.bottom, 10)
            
            // Bagian Main content area
            VStack(alignment: .leading, spacing: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(0..<totalPoses, id: \.self) { index in
                            let isWrong = (trainingResult?.poseDetails[safe: index]?.isCompletedCorrectly == false)
                            Button(action: {
                                selectedExercise = index
                            }) {
                                Image("iconA\(index + 1)")
                                    .renderingMode(.original)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .font(.title2)
                                    .frame(width: 55, height: 55)
                                    .background(selectedExercise == index ? Color.white : Color.white.opacity(0.4))
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(isWrong ? Color.red : Color.clear, lineWidth: 4)
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 30)
                .padding(.top, 15)
                .padding(.bottom, 15)
                
                Text("A\(selectedExercise + 1) (Gerakan \(selectedExercise + 1))")
                    .foregroundStyle(.white)
                    .font(.system(size: 27))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                
                // Exercise cards
                HStack(spacing: 25) {
                    // Primary exercise card - Ideal Pose
                    VStack(alignment: .leading) {
                        Text("Gerakan Ideal")
                        
                        // TODO: Tambahkan gambar pose ideal di sini
                        // Untuk saat ini kosongkan dengan background putih
                        Image("A\(selectedExercise + 1)")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .background(Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                    
                    // Secondary exercise card - User's Pose
                    VStack(alignment: .leading) {
                        Text("Gerakan Kamu")
                        
                        // Box dengan ukuran tetap untuk foto
                        ZStack {
                            // Background box putih dengan ukuran tetap
                            Rectangle()
                                .fill(Color.white)
                                .cornerRadius(15)
                                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .frame(height: 220)
                            
                            if let poseDetails = trainingResult?.poseDetails,
                               selectedExercise < poseDetails.count,
                               let userImage = poseDetails[selectedExercise].userPoseImage {
                                
                                // Tampilkan gambar user dari data dengan overlay joint
                                ZStack {
                                    // Gambar user - menggunakan aspectRatio .fill dan clipped
                                    Image(uiImage: userImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(maxWidth: .infinity)
                                        .frame(height: 220)
                                        .clipped()
                                    
                                    // Overlay untuk joints
                                    if let poseData = trainingResult?.poseDetails[selectedExercise].jointPositions {
                                        let idealJoints = trainingResult?.poseDetails[selectedExercise].idealJointPositions
                                        PoseSkeletonOverlayView(jointPositions: poseData, idealJointPositions: idealJoints)
                                            .frame(height: 220)
                                    }
                                }
                            } else {
                                // Fallback ke placeholder kosong
                                Text("Tidak ada data pose")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                
                Spacer()
                
                Button(action: {
                    resetToHome()
                }) {
                    Text("Selesai")
                        .font(.title2)
                        .foregroundColor(.black)
                        .fontWeight(.medium)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 30)
            .background(Color.silatD)
            .padding(.top, 25)
            .ignoresSafeArea()
        }
        .background(.silatB)
        .animation(.easeInOut(duration: 0.3), value: selectedExercise)
        .navigationBarBackButtonHidden(true)
    }
}

struct Exercise {
    let icon: String
    let name: String
    let secondaryIcon: String
    let items: [String]
}

// Extension untuk akses aman ke array
extension Array {
    subscript(safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    RekapLatihanView {
        
    }
}
