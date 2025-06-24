import Foundation
import SwiftUI
import Vision

/// Represents the different phases of training exercises
enum LatihanPhase {
    case positioning  // User is getting into position
    case countdown    // Countdown before starting the exercise
    case evaluating   // Evaluating the user's pose against the target pose
}

/// ViewModel that manages the training exercise flow, pose matching, timers, and feedback.
/// Handles user positioning, pose evaluation, and progression through multiple poses.
class LatihanViewModel: ObservableObject, PoseTimerManagerDelegate {
    // - Published Properties (for UI)
    @Published var currentPoseIndex: Int = 0
    @Published var isPoseMatched: Bool = false      // Whether the current pose is matched
    @Published var holdProgress: Double = 0.0       // Progress of holding the current pose (0.0 to 1.0)
    @Published var countdownValue: Int = 8          // Countdown seconds for holding a pose
    @Published var showCompletionMessage: Bool = false  // Whether to show completion message
    @Published var showPoseTransition: Bool = false     // Whether transitioning between poses
    @Published var isAtOptimalDistance: Bool = true     // Whether user is at optimal distance for detection
    @Published var poseName: String = "A1"              // Current pose name for display
    @Published var isMuted: Bool = false               // Whether voice instructions are muted
    @Published var isPaused: Bool = false              // Whether the session is paused
    
    // - Session timer properties
    @Published var sessionElapsedTime: String = "00:00"  // Formatted elapsed time for display
    @Published var sessionDuration: TimeInterval = 0     // Total session duration in seconds
    
    // - Positioning and countdown properties
    @Published var phase: LatihanPhase = .positioning   // Current phase of exercise
    @Published var positioningCountdownValue: Int = 3   // Countdown before starting pose evaluation
    @Published var isUserPositioned: Bool = false       // Whether user is properly positioned
    
    //  - ViewModels and Managers
    private var poseViewModel: PoseEstimationViewModel  // Handles pose detection
    private var poseMatcher: PoseMatcher                // Matches detected pose with target pose
    private var voiceFeedbackManager: VoiceFeedbackManager  // Provides voice guidance
    public var poseTimerManager: PoseTimerManager       // Manages pose holding time
    private var hasNavigatedToFinish: Bool = false      // Flag to track if we've navigated to finish view
    
    // Navigation callback for auto-navigation to finish view
    var navigateToFinish: (() -> Void)?

    //   - Properties
    let poseData: [PoseData]                           // Collection of target poses
    private var wasAtOptimalDistance: Bool = true      // Previous optimal distance state
    private var lastCorrectionTime: Date = .distantPast  // Last time correction was given
    private let correctionGracePeriod: TimeInterval = 2.0  // Seconds to wait before giving another correction
    private var countdownTimer: Timer?                  // Timer for positioning countdown
    private let fittingBox = CGRect(x: 0.15, y: 0.1, width: 0.7, height: 0.8)  // Area where user should position
    private var lastPoseValidStatus: Bool = false       // Track last pose validation status for logging
    
    // - Tracking pose accuracy and results
    private var poseFirstAttemptSuccess: [Int: Bool] = [:] // Track if pose was completed correctly on first attempt
    private var poseTimeToComplete: [Int: Double] = [:]    // Track time to complete each pose
    private var poseUserImages: [Int: UIImage] = [:]       // Store images of user for each pose
    private var poseJointPositions: [Int: [String: CGPoint]] = [:] // Store joint positions for each pose
    private var poseAttemptStartTime: Date?                // When user started attempting current pose
    private var poseMadeError: Bool = false                // If user made an error during countdown
    private var poseTransitionCount: Int = 0               // Count of pose transitions (splash screens)
    
    // - Session timer properties
    private var sessionTimer: Timer?                    // Timer for tracking session duration
    private var sessionStartTime: Date?                 // When the session started
    private var sessionPauseTime: TimeInterval = 0      // Time accumulated before pause
    private var actualTrainingStartTime: Date?          // When user actually started training (after fitting box)
    private var actualTrainingEndTime: Date?            // When user actually ended training (after fitting box)
    
    //   - Computed Properties

    
    /// The current target pose that the user should match
    var currentTargetPose: PoseData? {
        guard currentPoseIndex < poseData.count else { return nil }
        return poseData[currentPoseIndex]
    }

    /// The next target pose in the sequence
    var nextTargetPose: PoseData? {
        let nextIndex = currentPoseIndex + 1
        guard nextIndex < poseData.count else { return nil }
        return poseData[nextIndex]
    }

    //   - Initialization
    
    /// Initializes the view model with a pose detection view model
    /// - Parameter poseViewModel: The view model responsible for pose detection
    init(poseViewModel: PoseEstimationViewModel) {
        self.poseViewModel = poseViewModel
        self.poseData = PoseLoader.loadPose()
        
        print("LatihanViewModel: Loaded \(poseData.count) poses")
        for (index, pose) in poseData.enumerated() {
            print("Pose \(index): ID \(pose.poseId)")
        }
        
        self.poseMatcher = PoseMatcher(poseData: poseData, poseViewModel: poseViewModel)
        self.poseTimerManager = PoseTimerManager()
        // Must be initialized after self is available
        self.voiceFeedbackManager = VoiceFeedbackManager(poseViewModel: poseViewModel, poseData: poseData)
        
        self.poseTimerManager.delegate = self
        
        updatePoseName()
    }
    
    /// Cleans up timers and resources
    func cleanup() {
        poseTimerManager.stopTimer()
        countdownTimer?.invalidate()
        countdownTimer = nil
        stopSessionTimer()
    }
    
    // - Session Timer Methods
    
    /// Starts the session timer to track total training duration
    private func startSessionTimer() {
        guard sessionTimer == nil else { return }
        
        sessionStartTime = Date()
        sessionDuration = 0
        
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.sessionStartTime else { return }
            
            self.sessionDuration = Date().timeIntervalSince(startTime)
            self.updateSessionElapsedTime()
        }
    }
    
    /// Stops the session timer
    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }
    
    /// Updates the formatted elapsed time string
    private func updateSessionElapsedTime() {
        let minutes = Int(sessionDuration) / 60
        let seconds = Int(sessionDuration) % 60
        sessionElapsedTime = String(format: "%02d:%02d", minutes, seconds)
    }
    
    //   - Main Logic
    
    /// Updates the training state based on user position and current phase
    /// Called regularly to process new pose detection data
    func update() {
        self.isUserPositioned = checkUserPosition()

        switch phase {
        case .positioning:
            if isUserPositioned {
                startPositioningCountdown()
            }
        case .countdown:
            if !isUserPositioned {
                resetToPositioningPhase()
            }
        case .evaluating:
            evaluatePose()
        }
    }

    /// Evaluates the detected pose against the target pose and provides feedback
    private func evaluatePose() {
        // Skip evaluation if paused
        if isPaused {
            return
        }
        
        self.isAtOptimalDistance = checkOptimalDistance()
        
        // Announce change in distance status
        if isAtOptimalDistance != wasAtOptimalDistance && !isMuted {
            voiceFeedbackManager.announceDistance(isOptimal: isAtOptimalDistance, wasOptimal: wasAtOptimalDistance)
            wasAtOptimalDistance = isAtOptimalDistance
        }
        
        // Skip evaluation during pose transitions
        guard !showPoseTransition else { return }
        
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
        
        // Check if the detected pose matches the target pose
        let poseMatches = isAtOptimalDistance && poseMatcher.checkPoseMatch(currentPoseIndex: currentPoseIndex)
        
        if poseMatches && !isInGracePeriod {
            if !isPoseMatched {
                isPoseMatched = true
                
                if !isMuted {
                    voiceFeedbackManager.announcePoseMatch()
                }
                
                poseTimerManager.startTimer()
            }
        } else {
            if isPoseMatched {
                // This state is handled by the timer manager's delegate callbacks
            } else if isAtOptimalDistance && !isInGracePeriod && !isMuted {
                if let targetPose = currentTargetPose {
                    voiceFeedbackManager.giveJointCorrection(isPoseMatched: isPoseMatched, currentTargetPose: targetPose)
                }
            }
        }
    }

    //   - PoseTimerManagerDelegate
    
    /// Called when the pose has been held for the required duration
    func poseTimerDidComplete() {
        isPoseMatched = false
        
        // Calculate time to complete this pose
        if let startTime = poseAttemptStartTime {
            let completionTime = Date().timeIntervalSince(startTime)
            poseTimeToComplete[currentPoseIndex] = completionTime
            print("⏱️ Pose A\(currentPoseIndex + 1) selesai dalam \(String(format: "%.2f", completionTime)) detik")
        }
        
        // Pastikan kita memiliki gambar untuk pose ini
        if poseUserImages[currentPoseIndex] == nil {
            if let frame = poseViewModel.currentFrame {
                print("📸 Mengambil gambar akhir untuk pose A\(currentPoseIndex + 1) saat selesai")
                poseUserImages[currentPoseIndex] = frame
                
                // Save joint positions
                if let joints = convertJointPositionsToStringKeys(poseViewModel.detectedBodyParts) {
                    poseJointPositions[currentPoseIndex] = joints
                    print("📊 Menyimpan \(joints.count) joint positions akhir untuk pose A\(currentPoseIndex + 1)")
                }
            }
        }
        
        // Pose terakhir adalah currentPoseIndex == (poseData.count - 1)
        let isLastPose = (currentPoseIndex >= poseData.count - 1)
        print("🔄 Pose A\(currentPoseIndex + 1) selesai. Apakah ini pose terakhir? \(isLastPose)")
        
        if !isLastPose {
            showPoseTransition = true
            // Increment transition count
            poseTransitionCount += 1
            
            let completionText = "Bagus! Lanjut ke gerakan berikutnya"
            if !isMuted {
                voiceFeedbackManager.speak(completionText, interrupt: true) {
                    // This closure will execute ONLY AFTER the "Bagus!..." voice has finished
                    self.currentPoseIndex += 1
                    print("🔄 Pindah ke pose berikutnya: A\(self.currentPoseIndex + 1)")
                    self.updatePoseName()
                    self.showPoseTransition = false
                    self.resetForNextPose()
                }
            } else {
                // If muted, still execute the callback
                self.currentPoseIndex += 1
                print("🔄 Pindah ke pose berikutnya: A\(self.currentPoseIndex + 1) (muted)")
                self.updatePoseName()
                self.showPoseTransition = false
                self.resetForNextPose()
            }
        } else {
            // Sudah di pose terakhir, navigasi ke finish
            print("🏁 SELESAI: Ini adalah pose terakhir (A\(currentPoseIndex + 1) dari \(poseData.count))")
            showCompletionMessage = true
            
            // Pastikan timer berhenti
            poseTimerManager.stopTimer()
            stopSessionTimer()
            
            // Set waktu akhir latihan untuk perhitungan durasi
            actualTrainingEndTime = Date()
            
            // Buat hasil training
            print("📊 Membuat hasil training dari \(poseData.count) pose...")
            let trainingResult = generateTrainingResult()
            
            // Simpan hasil ke service
            TrainingResultService.shared.saveTrainingResult(trainingResult)
            print("💾 Hasil latihan berhasil disimpan. Durasi: \(trainingResult.duration)s, Benar: \(trainingResult.correctPoses)/\(trainingResult.totalPoses)")
            
            // Cek apakah sudah pernah navigasi ke FinishView
            if !hasNavigatedToFinish {
                print("🔀 Navigasi ke RekapView...")
                
                // Set flag untuk mencegah navigasi berulang
                hasNavigatedToFinish = true
                
                // Jalankan navigasi sekali saja pada UI thread
                DispatchQueue.main.async {
                    self.navigateToFinish?()
                }
            } else {
                print("⚠️ Sudah pernah navigasi ke RekapView, abaikan")
            }
            
            // Suara tetap dijalankan secara terpisah
            if !isMuted {
                voiceFeedbackManager.speak("Selamat! Semua gerakan telah diselesaikan.", interrupt: true)
            }
        }
    }
    
    /// Menghasilkan objek TrainingResult dari sesi latihan saat ini
    private func generateTrainingResult() -> TrainingResult {
        // Hitung jumlah pose yang benar dalam percobaan pertama
        let correctPosesCount = poseFirstAttemptSuccess.values.filter { $0 }.count
        
        // Hitung durasi yang sebenarnya (mengurangi waktu transisi)
        var actualDuration: Int = 0
        if let startTime = actualTrainingStartTime {
            // Durasi = waktu dari mulai latihan (fitting box pertama) - (jumlah transisi * 2 detik)
            let rawDuration = Int(Date().timeIntervalSince(startTime))
            let transitionDeduction = poseTransitionCount * 2  // 2 detik per transisi
            actualDuration = max(0, rawDuration - transitionDeduction)
        } else {
            actualDuration = Int(sessionDuration)
        }
        
        // Set waktu selesai latihan untuk perhitungan durasi
        if actualTrainingStartTime != nil && actualTrainingEndTime == nil {
            actualTrainingEndTime = Date()
        }
        
        // Pastikan semua pose memiliki data (bahkan jika hanya placeholder)
        ensureAllPosesHaveData()
        
        // Buat detail untuk setiap pose
        var poseDetails = [PoseDetail]()
        
        for index in 0..<poseData.count {
            let pose = poseData[index]
            let poseName = "A\(index + 1)"
            let isCorrect = poseFirstAttemptSuccess[index] ?? false
            let timeToComplete = poseTimeToComplete[index] ?? 0.0
            
            // Ambil data gambar dan joint jika ada
            let userImage = poseUserImages[index]
            let jointPositions = poseJointPositions[index]
            
            // Gunakan placeholder image jika tidak ada gambar
            // TODO: Tambahkan idealPoseImage jika tersedia
            let idealImage: UIImage? = nil
            
            let poseDetail = PoseDetail(
                poseName: poseName,
                poseId: pose.poseId,
                isCompletedCorrectly: isCorrect,
                timeToComplete: timeToComplete,
                userPoseImage: userImage,
                idealPoseImage: idealImage,
                jointPositions: jointPositions
            )
            
            poseDetails.append(poseDetail)
        }
        
        return TrainingResult(
            duration: actualDuration,
            totalPoses: poseData.count,
            correctPoses: correctPosesCount,
            poseDetails: poseDetails
        )
    }
    
    /// Memastikan semua pose memiliki data, bahkan jika belum dicoba
    private func ensureAllPosesHaveData() {
        print("Memastikan semua pose memiliki data...")
        
        // Cari pose yang berhasil sebagai alternatif
        var successfulPoseImage: UIImage? = nil
        var successfulJointPositions: [String: CGPoint]? = nil
        
        // Cari pose sukses pertama untuk dijadikan template
        for index in 0..<poseData.count {
            if let image = poseUserImages[index], let joints = poseJointPositions[index], !joints.isEmpty {
                successfulPoseImage = image
                successfulJointPositions = joints
                break
            }
        }
        
        // Jika tidak ada pose sukses sama sekali, gunakan frame dan joints terakhir yang tersedia
        if successfulPoseImage == nil {
            if let currentFrame = poseViewModel.currentFrame {
                successfulPoseImage = currentFrame
                successfulJointPositions = convertJointPositionsToStringKeys(poseViewModel.detectedBodyParts)
            } else {
                // Jika tidak ada frame sama sekali, buat placeholder kosong
                successfulPoseImage = createPlaceholderImage()
                successfulJointPositions = createPlaceholderJoints()
            }
        }
        
        // Loop through all poses to ensure they have data
        for index in 0..<poseData.count {
            print("Mengecek data pose \(index+1)...")
            
            // Jika pose tidak memiliki data gambar
            if poseUserImages[index] == nil {
                print("Pose \(index+1) tidak memiliki gambar, menambahkan placeholder...")
                poseUserImages[index] = successfulPoseImage
            }
            
            // Jika pose tidak memiliki data joint positions
            if poseJointPositions[index] == nil || poseJointPositions[index]?.isEmpty == true {
                print("Pose \(index+1) tidak memiliki joint positions, menambahkan placeholder...")
                poseJointPositions[index] = successfulJointPositions
            }
            
            // Pastikan nilai-nilai lainnya juga terisi
            poseFirstAttemptSuccess[index] = poseFirstAttemptSuccess[index] ?? false
            poseTimeToComplete[index] = poseTimeToComplete[index] ?? 0.0
        }
    }
    
    /// Creates a placeholder image for poses without data
    private func createPlaceholderImage() -> UIImage {
        let size = CGSize(width: 300, height: 400)
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        if let context = UIGraphicsGetCurrentContext() {
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            
            // Tambahkan teks placeholder
            let text = "Tidak ada data pose"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 18),
                .foregroundColor: UIColor.gray
            ]
            
            let textSize = text.size(withAttributes: attributes)
            let rect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            text.draw(in: rect, withAttributes: attributes)
        }
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
    }
    
    /// Creates placeholder skeleton data
    private func createPlaceholderJoints() -> [String: CGPoint] {
        // Normalized coordinates (0-1 range)
        return [
            "nose": CGPoint(x: 0.5, y: 0.2),
            "neck": CGPoint(x: 0.5, y: 0.3),
            "leftShoulder": CGPoint(x: 0.6, y: 0.3),
            "rightShoulder": CGPoint(x: 0.4, y: 0.3),
            "leftElbow": CGPoint(x: 0.7, y: 0.4),
            "rightElbow": CGPoint(x: 0.3, y: 0.4),
            "leftWrist": CGPoint(x: 0.7, y: 0.5),
            "rightWrist": CGPoint(x: 0.3, y: 0.5),
            "leftHip": CGPoint(x: 0.55, y: 0.6),
            "rightHip": CGPoint(x: 0.45, y: 0.6),
            "leftKnee": CGPoint(x: 0.55, y: 0.8),
            "rightKnee": CGPoint(x: 0.45, y: 0.8),
            "leftAnkle": CGPoint(x: 0.55, y: 0.95),
            "rightAnkle": CGPoint(x: 0.45, y: 0.95)
        ]
    }
    
    /// Called when the pose is no longer held correctly during the timer
    func poseTimerDidFail() {
        voiceFeedbackManager.announcePoseFailure()
        lastCorrectionTime = Date()
        isPoseMatched = false
        holdProgress = 0.0
        countdownValue = 8
    }
    
    /// Called when the timer updates with new countdown value and progress
    func poseTimerDidUpdate(countdown: Int, progress: Double) {
        if self.countdownValue != countdown && countdown > 0 {
             voiceFeedbackManager.announceHoldCountdown(second: countdown)
        }
        self.countdownValue = countdown
        self.holdProgress = progress
    }
    
    /// Checks if the current pose is still valid for timing
    /// - Returns: Boolean indicating if the pose is still valid
    func isPoseStillValid() -> Bool {
        // Jika sudah di pose terakhir, pastikan tetap valid untuk menyelesaikan timer
        if currentPoseIndex >= poseData.count - 1 && holdProgress > 0.5 {
            print("Di pose terakhir dengan progress > 50%, forcing pose tetap valid")
            return true
        }
        
        let timeSinceCorrection = Date().timeIntervalSince(lastCorrectionTime)
        let isInGracePeriod = timeSinceCorrection < correctionGracePeriod
        
        let isValid = isAtOptimalDistance && poseMatcher.checkPoseMatch(currentPoseIndex: currentPoseIndex) && !isInGracePeriod
        
        // Hanya log jika status validasi berubah
        if isValid != lastPoseValidStatus {
            print("isPoseStillValid: \(isValid), poseIndex: \(currentPoseIndex), atOptimalDistance: \(isAtOptimalDistance)")
            lastPoseValidStatus = isValid
        }
        
        return isValid
    }
    
    //   - Private Helpers
    
    /// Checks if the user is properly positioned within the fitting box
    /// - Returns: Boolean indicating if user is properly positioned
    private func checkUserPosition() -> Bool {
        let allJointsVisible = checkOptimalDistance()
        
        if poseViewModel.detectedBodyParts.isEmpty {
            return false
        }
        
        // Check if all detected body parts are within the fitting box
        for point in poseViewModel.detectedBodyParts.values {
            if !fittingBox.contains(point) {
                return false
            }
        }
        
        return allJointsVisible
    }
    
    /// Starts the countdown before beginning pose evaluation
    private func startPositioningCountdown() {
        phase = .countdown
        positioningCountdownValue = 3
        
        // Reset error tracking for this pose attempt
        poseMadeError = false
        poseAttemptStartTime = Date()
        
        // Set actual training start time if this is the first pose
        if currentPoseIndex == 0 && actualTrainingStartTime == nil {
            actualTrainingStartTime = Date()
        }
        
        countdownTimer?.invalidate()
        
        // Start session timer if not already running (for first pose)
        if sessionTimer == nil && !isPaused {
            startSessionTimer()
        }
        
        print("⭐️ Mulai countdown untuk pose A\(currentPoseIndex + 1)")
        
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            self.positioningCountdownValue -= 1
            
            // Saat countdown = 1, SELALU ambil gambar pose untuk data rekap
            if self.positioningCountdownValue == 1 {
                if let frame = self.poseViewModel.currentFrame {
                    print("📸 MENGAMBIL GAMBAR pose A\(self.currentPoseIndex + 1) saat countdown = 1")
                    self.poseUserImages[self.currentPoseIndex] = frame
                    
                    // Save joint positions - convert to String keys
                    if let joints = self.convertJointPositionsToStringKeys(self.poseViewModel.detectedBodyParts) {
                        print("📊 Menyimpan \(joints.count) joint positions untuk pose A\(self.currentPoseIndex + 1)")
                        self.poseJointPositions[self.currentPoseIndex] = joints
                        // Hanya tandai sukses jika tidak ada error
                        if !self.poseMadeError {
                            self.poseFirstAttemptSuccess[self.currentPoseIndex] = true
                        }
                    } else {
                        print("❌ Tidak dapat mengambil joint positions untuk pose A\(self.currentPoseIndex + 1)")
                    }
                } else {
                    print("❌ Tidak dapat mengambil frame untuk pose A\(self.currentPoseIndex + 1)")
                }
            }
            
            if self.positioningCountdownValue > 0 {
                if !self.isMuted {
                    self.voiceFeedbackManager.speak("\(self.positioningCountdownValue)", interrupt: true)
                }
            }
            
            if self.positioningCountdownValue <= 0 {
                self.countdownTimer?.invalidate()
                self.phase = .evaluating
                
                // Cek sekali lagi apakah data sudah tersimpan
                if self.poseUserImages[self.currentPoseIndex] == nil {
                    if let frame = self.poseViewModel.currentFrame {
                        print("🔄 Mengambil cadangan gambar pose A\(self.currentPoseIndex + 1) saat countdown berakhir")
                        self.poseUserImages[self.currentPoseIndex] = frame
                        
                        // Save joint positions
                        if let joints = self.convertJointPositionsToStringKeys(self.poseViewModel.detectedBodyParts) {
                            self.poseJointPositions[self.currentPoseIndex] = joints
                        }
                    }
                } else {
                    print("✅ Gambar untuk pose A\(self.currentPoseIndex + 1) sudah tersimpan sebelumnya")
                }
                
                if !self.isMuted {
                    self.voiceFeedbackManager.speak("Mulai!", interrupt: true)
                }
            }
        }
    }
    
    /// Resets back to positioning phase when user moves out of position
    private func resetToPositioningPhase() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        phase = .positioning
        positioningCountdownValue = 3
        
        // Mark that an error occurred during countdown for this pose
        poseMadeError = true
        
        print("🔴 User keluar dari posisi saat countdown pose A\(currentPoseIndex + 1), kembali ke positioning")
        
        // Capture frame showing the error with joint positions
        if let frame = poseViewModel.currentFrame {
            print("📸 Mengambil gambar error pose A\(currentPoseIndex + 1)")
            // Tetap simpan gambar meskipun error
            poseUserImages[currentPoseIndex] = frame
            
            // Save joint positions - convert to String keys
            if let joints = convertJointPositionsToStringKeys(poseViewModel.detectedBodyParts) {
                print("📊 Menyimpan \(joints.count) joint positions untuk pose error A\(currentPoseIndex + 1)")
                poseJointPositions[currentPoseIndex] = joints
            }
        } else {
            print("❌ Tidak dapat mengambil frame error untuk pose A\(currentPoseIndex + 1)")
        }
        
        if !isMuted {
            voiceFeedbackManager.speak("Posisi salah, kembali ke dalam kotak", interrupt: true)
        }
    }
    
    /// Checks if all required joints are visible for optimal pose detection
    /// - Returns: Boolean indicating if all required joints are detected
    private func checkOptimalDistance() -> Bool {
        let requiredJoints: [HumanBodyPoseObservation.JointName] = [
            .nose, .neck, .leftShoulder, .rightShoulder, .leftElbow, .rightElbow,
            .leftWrist, .rightWrist, .leftHip, .rightHip, .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        return requiredJoints.allSatisfy { poseViewModel.detectedBodyParts[$0] != nil }
    }
    
    /// Resets all state variables for the next pose
    private func resetForNextPose() {
        isPoseMatched = false
        holdProgress = 0.0
        countdownValue = 8
        lastCorrectionTime = .distantPast
    }
    
    /// Updates the display name of the current pose
    private func updatePoseName() {
        if currentPoseIndex < poseData.count {
            poseName = "A\(currentPoseIndex + 1)"
        }
    }

    /// Toggles voice instructions mute state
    func toggleMute() {
        isMuted = !isMuted
        voiceFeedbackManager.setMuted(isMuted)
    }
    
    /// Toggles pause state for the training session
    func togglePause() {
        isPaused = !isPaused
        
        if isPaused {
            // Pause the session timer
            sessionTimer?.invalidate()
            sessionTimer = nil
            
            // Store the current accumulated time
            if let startTime = sessionStartTime {
                sessionPauseTime = sessionDuration
            }
            
            // Pause pose timer if it's running
            if isPoseMatched {
                poseTimerManager.pauseTimer()
            }
            
            // Pause countdown timer if in that phase
            if phase == .countdown {
                countdownTimer?.invalidate()
                countdownTimer = nil
            }
            
            // Voice announcement
            if !isMuted {
                voiceFeedbackManager.speak("Sesi latihan dijeda", interrupt: true)
            }
        } else {
            // Resume session timer with accumulated time
            sessionStartTime = Date().addingTimeInterval(-sessionPauseTime)
            startSessionTimer()
            
            // Resume pose timer if needed
            if isPoseMatched {
                poseTimerManager.resumeTimer()
            }
            
            // Resume countdown if in that phase
            if phase == .countdown {
                startPositioningCountdown()
            }
            
            // Voice announcement
            if !isMuted {
                voiceFeedbackManager.speak("Melanjutkan sesi latihan", interrupt: true)
            }
        }
    }
    
    /// Converts joint positions to String keys
    private func convertJointPositionsToStringKeys(_ positions: [HumanBodyPoseObservation.JointName: CGPoint]) -> [String: CGPoint]? {
        // Jika tidak ada data joint, return nil
        guard !positions.isEmpty else {
            print("❌ Tidak ada data joint positions yang tersedia")
            return nil
        }
        
        var stringPositions: [String: CGPoint] = [:]
        
        do {
            for (joint, position) in positions {
                // Konversi ke string berdasarkan nama joint
                let jointNameString = jointNameToString(joint)
                stringPositions[jointNameString] = position
            }
            
            // Pastikan setidaknya beberapa joint penting ada
            let requiredJoints = ["nose", "neck", "leftShoulder", "rightShoulder"]
            let hasRequiredJoints = requiredJoints.allSatisfy { stringPositions[$0] != nil }
            
            if !hasRequiredJoints {
                print("⚠️ Data joint tidak lengkap, beberapa joint penting tidak terdeteksi")
            }
            
            return stringPositions
        } catch {
            print("❌ Error saat konversi joint positions: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Convert HumanBodyPoseObservation.JointName to String
    private func jointNameToString(_ jointName: HumanBodyPoseObservation.JointName) -> String {
        switch jointName {
        case .nose: return "nose"
        case .neck: return "neck"
        case .leftShoulder: return "leftShoulder"
        case .rightShoulder: return "rightShoulder"
        case .leftElbow: return "leftElbow"
        case .rightElbow: return "rightElbow"
        case .leftWrist: return "leftWrist"
        case .rightWrist: return "rightWrist"
        case .leftHip: return "leftHip"
        case .rightHip: return "rightHip"
        case .leftKnee: return "leftKnee"
        case .rightKnee: return "rightKnee"
        case .leftAnkle: return "leftAnkle"
        case .rightAnkle: return "rightAnkle"
        default: return "unknown"
        }
    }
} 
