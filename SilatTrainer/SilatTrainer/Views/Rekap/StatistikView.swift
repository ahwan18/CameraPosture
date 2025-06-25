import SwiftUI
import SwiftData
import Charts

struct StatistikView: View {
    @StateObject private var viewModel = StatistikViewModel()
    @State private var viewMode: ViewMode = .bulan
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    //    var navigate: (AppRoute) -> Void
    @State private var showResetConfirmation = false
    @State private var selected = 1
    
    enum ViewMode {
        case minggu, bulan
    }
    
    // Helper function to calculate an appropriate maximum Y value
    private func calculateYAxisMax(maxValue: Double) -> Double {
        if maxValue <= 0 {
            return 10 // Default if no data
        }
        
        // Round up to next increment of 5
        let increment = 5.0
        return ceil(maxValue / increment) * increment
    }
    
    // Helper function to generate Y-axis step values
    private func calculateYAxisSteps(maxValue: Double) -> [Double] {
        if maxValue <= 0 {
            return [0, 2, 4, 6, 8, 10]
        }
        
        let stepSize = maxValue <= 10 ? 2.0 : (maxValue <= 20 ? 5.0 : 10.0)
        let numberOfSteps = Int(ceil(maxValue / stepSize))
        
        var steps: [Double] = []
        for i in 0...numberOfSteps {
            steps.append(Double(i) * stepSize)
        }
        
        return steps
    }
    
    
    var body: some View {
        ZStack {
            // Background color
            Color("silatB")
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with back button
                //                HStack {
                //                    Button(action: {
                //                        dismiss()
                //                    }) {
                //                        HStack {
                //                            Image(systemName: "chevron.left")
                //                                .foregroundColor(.yellow)
                //                            Text("Kembali")
                //                                .foregroundColor(.yellow)
                //                                .fontWeight(.bold)
                //                        }
                //                    }
                //                    .padding(.leading, 24)
                //
                //                    Spacer()
                //                }
                //                .padding(.top, 8)
                
                // Title
                HStack {
                    Text("Ringkasan \(viewModel.selectedJurus)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.leading, 24)
                    
                    Spacer()
                    
                    // Reset button
                    Button(action: {
                        // Show confirmation alert
                        showResetConfirmation = true
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.yellow)
                    }
                    .padding(.trailing, 24)
                }
                .padding(.top, 25)
                
                //                // View mode selector (Minggu/Bulan)
                //                HStack(spacing: 0) {
                //                    Button(action: {
                //                        viewMode = .minggu
                //                        viewModel.loadStatistics(forViewMode: viewMode, using: modelContext)
                //                    }) {
                //                        Text("Minggu")
                //                            .font(.headline)
                //                            .foregroundColor(Color("silatC"))
                //                            .frame(maxWidth: .infinity)
                //                            .padding(.vertical, 12)
                //                            .background(viewMode == .minggu ? Color(.white) : Color.clear)
                //                    }
                //
                //                    Button(action: {
                //                        viewMode = .bulan
                //                        viewModel.loadStatistics(forViewMode: viewMode, using: modelContext)
                //                    }) {
                //                        Text("Bulan")
                //                            .font(.headline)
                //                            .foregroundColor(.black)
                //                            .frame(maxWidth: .infinity)
                //                            .padding(.vertical, 12)
                //                            .background(viewMode == .bulan ? Color(.white) : Color.clear)
                //                    }
                //                }
                //                .background(Color(.darkGray).opacity(0.4))
                //                .cornerRadius(8)
                //                .padding(.horizontal, 24)
                //                .padding(.top, 16)
                
                Picker(selection: $selected, label: Text("Picker")) {
                    Text("Minggu").tag(1)
                    Text("Bulan").tag(2)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .pickerStyle(SegmentedPickerStyle())
                .onAppear {
                    UISegmentedControl.appearance().backgroundColor = .segmentedBackground
                    UISegmentedControl.appearance().selectedSegmentTintColor = .white
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.gray], for: .normal)
                    UISegmentedControl.appearance().setTitleTextAttributes([.foregroundColor: UIColor.segmentedBackground], for: .selected)
                }
                .onChange(of: selected) { newValue in
                    // Change viewMode based on selected value
                    viewMode = (newValue == 1) ? .minggu : .bulan
                    viewModel.loadStatistics(forViewMode: viewMode, using: modelContext)
                }
                
                
                // Progress section
                VStack(spacing: 8) {
                    Text("Progres Kamu \(viewMode == .bulan ? "Bulan" : "Minggu") Ini")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 24)
                    
                    Text("\(viewModel.progressPercentage)%")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 12)
                }
                
                // Bar chart section - replacing with Swift Charts
                VStack(alignment: .leading, spacing: 0) {
                    // Text("Gerakan \(viewModel.selectedJurus)")
                    //     .font(.title3)
                    //     .fontWeight(.semibold)
                    //     .foregroundColor(.white)
                    //     .padding(.horizontal, 24)
                    //     .padding(.top, 16)
                    //     .padding(.bottom, 8)
                    
                    // Chart with background
                    ZStack(alignment: .center) {
                        // Background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(UIColor(red: 0.38, green: 0.22, blue: 0.22, alpha: 1.0)))
                            .padding(.horizontal, 8)
                        
                        VStack(alignment: .leading, spacing: 0) {
                            // Chart title & description
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gerakan \(viewModel.selectedJurus)")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                
                                Text("Jumlah keberhasilan gerakan tanpa mengulang saat fase menahan")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                            
                            // Swift Charts implementation with proper containment
                            VStack(spacing: 0) {
                                let poseData = viewMode == .bulan ? viewModel.monthlyPoseData : viewModel.weeklyPoseData
                                let chartData = poseData.map { key, value in
                                    return BarData(pose: key, value: Double(value))
                                }.sorted(by: { $0.pose < $1.pose })
                                
                                // Calculate Y-axis range
                                let maxValue = (chartData.map { $0.value }.max() ?? 0)
                                let yAxisMax = calculateYAxisMax(maxValue: maxValue)
                                let yAxisSteps = calculateYAxisSteps(maxValue: yAxisMax)
                                
                                // Container to enforce chart boundaries
                                Chart {
                                    ForEach(chartData, id: \.pose) { item in
                                        BarMark(
                                            x: .value("Pose", item.pose),
                                            y: .value("Success Count", item.value),
                                            width: .fixed(22)
                                        )
                                        .foregroundStyle(Color(UIColor(red: 0.28, green: 0.16, blue: 0.16, alpha: 1.0)))
                                        .cornerRadius(3)
                                    }
                                    
                                    // Add a hidden mark to ensure consistent scaling
                                    RuleMark(y: .value("Max", yAxisMax))
                                        .foregroundStyle(.clear)
                                }
                                .chartYAxis {
                                    AxisMarks(position: .leading, values: yAxisSteps) { value in
                                        AxisGridLine(centered: false, stroke: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                            .foregroundStyle(Color.white.opacity(0.3))
                                        
                                        AxisValueLabel() {
                                            if let intValue = value.as(Int.self) {
                                                Text("\(intValue)")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                }
                                .chartYScale(domain: 0...yAxisMax)
                                .chartXAxis {
                                    AxisMarks { value in
                                        AxisValueLabel {
                                            if let stringValue = value.as(String.self) {
                                                Text(stringValue)
                                                    .foregroundColor(.white)
                                                    .font(.system(size: 13, weight: .medium))
                                            }
                                        }
                                    }
                                }
                                .chartLegend(.hidden)
                                .frame(height: 250)
                            }
                            .padding(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                    }
                    .frame(height: 310)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Metrics cards
                HStack(spacing: 16) {
                    // Total Latihan card
                    VStack(alignment: .leading) {
                        Text("Total Latihan")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(viewModel.totalSessions)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("sesi")
                                .font(.callout)
                                .foregroundColor(.white)
                                .padding(.bottom, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(UIColor(red: 0.38, green: 0.22, blue: 0.22, alpha: 1.0)))
                    .cornerRadius(12)
                    
                    // Average Duration card
                    VStack(alignment: .leading) {
                        Text("Durasi")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text("\(viewModel.averageDuration)")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("dtk/sesi")
                                .font(.callout)
                                .foregroundColor(.white)
                                .padding(.bottom, 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(UIColor(red: 0.38, green: 0.22, blue: 0.22, alpha: 1.0)))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.top, 35)
                
                Spacer()
                
                //                // Tab Bar
                //                HStack {
                //                    Spacer()
                //
                //                    // Latihan Tab
                //                    Button(action: {
                //                        navigate(.latihan)
                //                    }) {
                //                        VStack {
                //                            Image(systemName: "figure.martial.arts")
                //                                .resizable()
                //                                .scaledToFit()
                //                                .frame(width: 30, height: 30)
                //
                //                            Text("Latihan")
                //                                .font(.caption)
                //                        }
                //                        .foregroundColor(.gray)
                //                        .frame(maxWidth: .infinity)
                //                    }
                //
                //                    Spacer()
                //
                //                    // Ringkasan Tab (currently active)
                //                    VStack {
                //                        Image(systemName: "star")
                //                            .resizable()
                //                            .scaledToFit()
                //                            .frame(width: 30, height: 30)
                //
                //                        Text("Ringkasan")
                //                            .font(.caption)
                //                    }
                //                    .foregroundColor(.yellow)
                //                    .frame(maxWidth: .infinity)
                //
                //                    Spacer()
                //                }
                //                .padding(.vertical, 10)
                //                .background(Color.black)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            viewModel.loadStatistics(forViewMode: viewMode, using: modelContext)
        }
        .alert("Reset Data", isPresented: $showResetConfirmation) {
            Button("Batal", role: .cancel) {}
            Button("Reset", role: .destructive) {
                viewModel.resetAllData(using: modelContext)
            }
        } message: {
            Text("Tindakan ini akan menghapus semua data latihan. Data yang dihapus tidak dapat dikembalikan.")
        }
    }
}

// Data structure for Chart
struct BarData {
    let pose: String
    let value: Double
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: TrainingSession.self, PoseResult.self, configurations: config)
    
    // Add sample data for preview
    let session1 = TrainingSession(jurus: "Jurus 1", duration: 180)
    session1.poseResults = [
        PoseResult(poseName: "A1", poseNumber: 1, isCorrect: true, holdDuration: 3.0),
        PoseResult(poseName: "A2", poseNumber: 2, isCorrect: true, holdDuration: 3.0),
        PoseResult(poseName: "A3", poseNumber: 3, isCorrect: false, holdDuration: 2.5),
        PoseResult(poseName: "A4", poseNumber: 4, isCorrect: true, holdDuration: 3.0),
        PoseResult(poseName: "A5", poseNumber: 5, isCorrect: true, holdDuration: 3.0),
        PoseResult(poseName: "A6", poseNumber: 6, isCorrect: false, holdDuration: 1.5),
        PoseResult(poseName: "A7", poseNumber: 7, isCorrect: true, holdDuration: 3.0)
    ]
    
    container.mainContext.insert(session1)
    
    return StatistikView(/*navigate: { _ in }*/)
        .modelContainer(container)
}
