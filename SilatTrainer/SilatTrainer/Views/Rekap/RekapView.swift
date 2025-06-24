import SwiftUI

struct RekapLatihanView: View {
    var resetToHome: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise = 0
    
    let second: Int = 20
    let maxPose: Int = 7
    let correctPose: Int = 5
    
    
    let exercises = [
        Exercise(
            icon: "iconA1",
            name: "A1",
            secondaryIcon: "figure.walk",
            items: [
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum"
            ]
        ),
        Exercise(
            icon: "figure.jumprope",
            name: "A2",
            secondaryIcon: "figure.arms.open",
            items: [
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum"
            ]
        ),
        Exercise(
            icon: "figure.strengthtraining.traditional",
            name: "A3",
            secondaryIcon: "figure.pushup",
            items: [
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum"
            ]
        ),
        Exercise(
            icon: "figure.squat",
            name: "A4",
            secondaryIcon: "figure.flexibility",
            items: [
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum"
            ]
        ),
        Exercise(
            icon: "figure.climbing",
            name: "A5",
            secondaryIcon: "figure.core.training",
            items: [
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum"
            ]
        ),
        Exercise(
            icon: "figure.yoga",
            name: "A6",
            secondaryIcon: "figure.mind.and.body",
            items: [
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum"
            ]
        ),
        Exercise(
            icon: "figure.boxing",
            name: "A7",
            secondaryIcon: "figure.kickboxing",
            items: [
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum",
                "Lorem Ipsum"
            ]
        )
    ]
    
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
                            Text("\(second)") // bisa ganti dengan variabel
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
                            Text("\(correctPose)/\(maxPose)") // bisa ganti dengan variabel
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
                        ForEach(0..<exercises.count, id: \.self) { index in
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
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 30)
                .padding(.top, 15)
                .padding(.bottom, 15)
                
                Text("\(exercises[selectedExercise].name)(Gerakan \(selectedExercise + 1))")
                    .foregroundStyle(.white)
                    .font(.system(size: 27))
                    .fontWeight(.semibold)
                    .padding(.horizontal, 20)
                
                // Exercise cards
                HStack(spacing: 25) {
                    // Primary exercise card
                    VStack(alignment: .leading) {
                        Text("Gerakan Ideal")
                        
                        Image(systemName: exercises[selectedExercise].icon)
                            .font(.system(size: 50))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                        
                    }
                    
                    // Secondary exercise card
                    VStack(alignment: .leading) {
                        Text("Gerakan Kamu")
                        
                        Image(systemName: exercises[selectedExercise].secondaryIcon)
                            .font(.system(size: 50))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 220)
                            .background(Color.white)
                            .cornerRadius(15)
                            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
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

#Preview {
    RekapLatihanView {
        
    }
}
