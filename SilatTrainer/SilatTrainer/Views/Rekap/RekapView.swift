import SwiftUI

struct RekapLatihanView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExercise = 0
    
    let exercises = [
        Exercise(
            icon: "figure.run",
            name: "Lari",
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
            name: "Jumping Jack",
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
            name: "Push Up",
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
            name: "Squat",
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
            name: "Mountain Climber",
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
            name: "Yoga",
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
            name: "Boxing",
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
            HStack {
                Spacer()
                Spacer()
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .frame(width: 35, height: 35)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black, lineWidth: 3)
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 30)
            
            VStack {
                Text("Rekap Latihan")
                    .font(.largeTitle)
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 30)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 15) {
                    ForEach(0..<exercises.count, id: \.self) { index in
                        Button(action: {
                            selectedExercise = index
                        }) {
                            Image(systemName: exercises[index].icon)
                                .font(.title2)
                                .foregroundColor(selectedExercise == index ? .white : .black)
                                .frame(width: 55, height: 55)
                                .background(selectedExercise == index ? Color.black : Color.gray.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 30)
            .padding(.top, 45)
            .padding(.bottom, 0)
            
            
            // Bagian Main content area
            VStack(spacing: 20) {
                // Exercise cards
                HStack(spacing: 25) {
                    // Primary exercise card
                    VStack {
                        Image(systemName: exercises[selectedExercise].icon)
                            .font(.system(size: 50))
                            .foregroundColor(.black)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                    
                    // Secondary exercise card
                    VStack {
                        Image(systemName: exercises[selectedExercise].secondaryIcon)
                            .font(.system(size: 50))
                            .foregroundColor(.black)
                        
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
                }
                .padding(.horizontal, 20)
                
                // Exercise items list
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<exercises[selectedExercise].items.count, id: \.self) { index in
                        HStack {
                            Text("\(index + 1). \(exercises[selectedExercise].items[index])")
                                .font(.body)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.top, 10)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 30)
            .background(Color.gray.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.top, 25)
            .ignoresSafeArea()
        }
        .background(Color.white)
        .animation(.easeInOut(duration: 0.3), value: selectedExercise)
    }
}

struct Exercise {
    let icon: String
    let name: String
    let secondaryIcon: String
    let items: [String]
}

// Preview
struct RekapLatihanView_Previews: PreviewProvider {
    static var previews: some View {
        RekapLatihanView()
    }
}
