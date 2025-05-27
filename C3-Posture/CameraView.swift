import SwiftUI
import AVFoundation  // Framework untuk kamera
import Vision        // Framework untuk Computer Vision (AI)
import Combine       // Framework untuk reactive programming
import ImageIO       // Untuk orientasi gambar

// MARK: - ViewModel untuk Kamera dan Deteksi Postur
// ObservableObject memungkinkan SwiftUI untuk bereaksi terhadap perubahan data
class CameraViewModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    // @Published membuat property ini dapat "diamati" oleh SwiftUI
    // Setiap perubahan akan memicu update UI secara otomatis
    
    @Published var session = AVCaptureSession()              // Session kamera utama
    @Published var isPostureGood = false                     // Status apakah postur sudah benar
    @Published var cameraPosition: AVCaptureDevice.Position = .back  // Posisi kamera (depan/belakang)
    @Published var currentPoseObservation: VNHumanBodyPoseObservation?  // Data pose tubuh dari Vision
    @Published var isPersonDetected = false                  // Apakah ada orang yang terdeteksi
    @Published var personBoundingBox: CGRect?               // Kotak pembatas orang yang terdeteksi
    @Published var isLeftElbowGood: Bool = true             // Status postur tangan kiri
    @Published var isRightElbowGood: Bool = true            // Status postur tangan kanan
    @Published var isSetupMode: Bool = true                 // Mode setup untuk menyimpan posisi target
    @Published var targetPersonBox: CGRect? = nil           // Posisi target yang disimpan saat setup
    
    // MARK: - Private Properties
    // Properties yang hanya digunakan internal dalam class ini
    private var videoDataOutput: AVCaptureVideoDataOutput?  // Output untuk menganalisis frame video
    private var videoDataOutputQueue: DispatchQueue?        // Queue untuk processing frame secara asynchronous
    
    // MARK: - Initializer
    // Konstruktor yang dipanggil saat objek dibuat
    override init() {
        super.init()
        setupCamera()  // Setup kamera saat objek dibuat
    }
    
    // MARK: - Setup Kamera
    // Fungsi untuk mengkonfigurasi session kamera
    func setupCamera() {
        // beginConfiguration() memungkinkan kita mengubah konfigurasi session
        session.beginConfiguration()
        
        // Set kualitas video ke high
        session.sessionPreset = .high
        
        // Hapus semua input yang sudah ada (untuk switch kamera)
        session.inputs.forEach { session.removeInput($0) }
        
        // Dapatkan device kamera berdasarkan posisi yang dipilih
        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                      for: .video,
                                                      position: cameraPosition) else { return }
        
        // Buat input dari device kamera
        guard let videoDeviceInput = try? AVCaptureDeviceInput(device: videoDevice) else { return }
        
        // Tambahkan input ke session jika memungkinkan
        guard session.canAddInput(videoDeviceInput) else { return }
        session.addInput(videoDeviceInput)
        
        // Setup output untuk mendapatkan frame video yang akan dianalisis
        let videoDataOutput = AVCaptureVideoDataOutput()
        // Set delegate untuk menerima callback setiap frame baru
        videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "VideoDataOutput", qos: .userInitiated))
        
        // Tambahkan output ke session
        guard session.canAddOutput(videoDataOutput) else { return }
        session.addOutput(videoDataOutput)
        
        // Simpan reference ke output dan queue
        self.videoDataOutput = videoDataOutput
        self.videoDataOutputQueue = DispatchQueue(label: "VideoDataOutput", qos: .userInitiated)
        
        // Commit semua perubahan konfigurasi
        session.commitConfiguration()
    }
    
    // MARK: - Switch Kamera
    // Fungsi untuk mengganti antara kamera depan dan belakang
    func switchCamera() {
        // Toggle posisi kamera
        cameraPosition = cameraPosition == .back ? .front : .back
        // Setup ulang kamera dengan posisi baru
        setupCamera()
    }
    
    // MARK: - Lifecycle Kamera
    // Fungsi untuk memulai session kamera
    func startSession() {
        if !session.isRunning {
            // Jalankan di background thread untuk tidak memblokir UI
            DispatchQueue.global(qos: .background).async {
                self.session.startRunning()
            }
        }
    }
    
    // Fungsi untuk menghentikan session kamera
    func stopSession() {
        if session.isRunning {
            session.stopRunning()
        }
    }
    
    // MARK: - Helper Functions
    // Fungsi untuk mengecek apakah bounding box berada di area tengah layar
    private func isInCenterArea(_ boundingBox: CGRect) -> Bool {
        let centerX = boundingBox.midX  // Titik tengah X dari bounding box
        let centerY = boundingBox.midY  // Titik tengah Y dari bounding box
        
        // Definisi area tengah (bisa disesuaikan)
        let centerAreaWidth: CGFloat = 0.4   // 40% dari lebar layar
        let centerAreaHeight: CGFloat = 0.4  // 40% dari tinggi layar
        
        // Hitung batas area tengah
        let minX = (1.0 - centerAreaWidth) / 2
        let maxX = minX + centerAreaWidth
        let minY = (1.0 - centerAreaHeight) / 2
        let maxY = minY + centerAreaHeight
        
        // Cek apakah titik tengah bounding box berada dalam area tengah
        return centerX >= minX && centerX <= maxX && centerY >= minY && centerY <= maxY
    }
}

// MARK: - Video Processing Delegate
// Extension untuk menangani frame video yang masuk dari kamera
extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    // Fungsi ini dipanggil setiap kali ada frame baru dari kamera
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Ekstrak pixel buffer dari sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // Tentukan orientasi gambar berdasarkan posisi kamera
        let orientation: CGImagePropertyOrientation
        if cameraPosition == .front {
            orientation = .leftMirrored  // Kamera depan perlu di-mirror
        } else {
            orientation = .right         // Kamera belakang
        }
        
        // MARK: - Setup Vision Requests
        // Buat request untuk deteksi manusia (bounding box)
        let personDetectionRequest = VNDetectHumanRectanglesRequest()
        // Buat request untuk deteksi pose tubuh (skeleton)
        let poseRequest = VNDetectHumanBodyPoseRequest()
        
        // Buat handler untuk memproses kedua request
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        
        do {
            // Jalankan kedua request secara bersamaan
            try handler.perform([personDetectionRequest, poseRequest])
            
            // Ambil hasil deteksi
            let personObservations = personDetectionRequest.results as? [VNHumanObservation] ?? []
            let poseObservations = poseRequest.results as? [VNHumanBodyPoseObservation] ?? []
            
            // Jika tidak ada orang yang terdeteksi
            if personObservations.isEmpty {
                DispatchQueue.main.async {
                    self.isPersonDetected = false
                    self.personBoundingBox = nil
                    self.currentPoseObservation = nil
                    self.isPostureGood = false
                }
                return
            }
            
            // MARK: - Helper Functions untuk Matching
            // Fungsi untuk mendapatkan titik tengah dari bounding box
            func boxCenter(_ box: CGRect) -> CGPoint {
                CGPoint(x: box.midX, y: box.midY)
            }
            
            // Fungsi untuk mendapatkan titik tengah dari pose (rata-rata bahu atau leher)
            func poseCenter(_ pose: VNHumanBodyPoseObservation) -> CGPoint? {
                if let left = try? pose.recognizedPoint(.leftShoulder),
                   let right = try? pose.recognizedPoint(.rightShoulder) {
                    // Gunakan rata-rata bahu kiri dan kanan
                    return CGPoint(x: (left.location.x + right.location.x)/2, 
                                 y: (left.location.y + right.location.y)/2)
                } else if let neck = try? pose.recognizedPoint(.neck) {
                    // Fallback ke leher jika bahu tidak terdeteksi
                    return neck.location
                }
                return nil
            }
            
            // Variables untuk menyimpan hasil seleksi
            var selectedBox: CGRect? = nil
            var selectedPose: VNHumanBodyPoseObservation? = nil
            
            // MARK: - Logic Pemilihan Person dan Pose
            if isSetupMode {
                // MODE SETUP: Pilih person dengan confidence tertinggi
                let best = personObservations.max { $0.confidence < $1.confidence }
                selectedBox = best?.boundingBox
                
                // Cari pose yang paling dekat dengan bounding box terpilih
                if let bestBox = selectedBox {
                    selectedPose = poseObservations.min(by: {
                        guard let c0 = poseCenter($0), let c1 = poseCenter($1) else { return false }
                        let d0 = distance(boxCenter(bestBox), c0)
                        let d1 = distance(boxCenter(bestBox), c1)
                        return d0 < d1
                    })
                }
            } else if let targetBox = targetPersonBox {
                // MODE EVALUASI: Cari person yang paling dekat dengan posisi target
                let best = personObservations.min(by: { 
                    distance(boxCenter($0.boundingBox), boxCenter(targetBox)) < 
                    distance(boxCenter($1.boundingBox), boxCenter(targetBox)) 
                })
                selectedBox = best?.boundingBox
                
                // Cari pose yang sesuai dengan person terpilih
                if let bestBox = selectedBox {
                    selectedPose = poseObservations.min(by: {
                        guard let c0 = poseCenter($0), let c1 = poseCenter($1) else { return false }
                        let d0 = distance(boxCenter(bestBox), c0)
                        let d1 = distance(boxCenter(bestBox), c1)
                        return d0 < d1
                    })
                }
            }
            
            // MARK: - Update UI di Main Thread
            DispatchQueue.main.async {
                self.isPersonDetected = selectedBox != nil
                self.personBoundingBox = selectedBox
                self.currentPoseObservation = selectedPose
                
                if self.isSetupMode {
                    // Dalam setup mode, jangan analisis postur
                    self.isPostureGood = false
                } else if let pose = selectedPose {
                    // Analisis postur jika ada pose yang terdeteksi
                    self.analyzePosture(pose)
                } else {
                    // Tidak ada pose, postur dianggap tidak bagus
                    self.isPostureGood = false
                }
            }
            
        } catch {
            print("Failed to perform Vision request: \(error)")
        }
    }
    
    // MARK: - Analisis Postur
    // Fungsi untuk menganalisis apakah postur tubuh sudah sesuai target
    private func analyzePosture(_ observation: VNHumanBodyPoseObservation) {
        // Dapatkan key points untuk kedua lengan
        guard let leftShoulder = try? observation.recognizedPoint(.leftShoulder),
              let leftElbow = try? observation.recognizedPoint(.leftElbow),
              let leftWrist = try? observation.recognizedPoint(.leftWrist),
              let rightShoulder = try? observation.recognizedPoint(.rightShoulder),
              let rightElbow = try? observation.recognizedPoint(.rightElbow),
              let rightWrist = try? observation.recognizedPoint(.rightWrist) else {
            return
        }

        // Hitung sudut lengan kiri (bahu–siku–pergelangan)
        let leftArmAngle = angleBetween(p1: leftShoulder.location, 
                                     vertex: leftElbow.location, 
                                     p3: leftWrist.location)
        
        // Hitung sudut lengan kanan (bahu–siku–pergelangan)
        let rightArmAngle = angleBetween(p1: rightShoulder.location, 
                                       vertex: rightElbow.location, 
                                       p3: rightWrist.location)

        // MARK: - Konfigurasi Target Postur
        let targetArmAngle: CGFloat = 170 // Target sudut untuk postur tangan ke atas (dalam derajat)
        let tolerance: CGFloat = 10       // Toleransi derajat (range 160–180 dianggap bagus)

        // Evaluasi apakah setiap lengan sudah dalam posisi yang benar
        let leftIsGood = abs(leftArmAngle - targetArmAngle) < tolerance
        let rightIsGood = abs(rightArmAngle - targetArmAngle) < tolerance

        // Update status di main thread
        DispatchQueue.main.async {
            self.isPostureGood = leftIsGood && rightIsGood  // Kedua lengan harus bagus
            self.isLeftElbowGood = leftIsGood
            self.isRightElbowGood = rightIsGood
        }
    }

    // MARK: - Helper Functions untuk Geometri
    // Fungsi untuk menghitung sudut antara tiga titik dalam derajat
    private func angleBetween(p1: CGPoint, vertex: CGPoint, p3: CGPoint) -> CGFloat {
        // Buat vector dari vertex ke p1 dan p3
        let v1 = CGVector(dx: p1.x - vertex.x, dy: p1.y - vertex.y)
        let v2 = CGVector(dx: p3.x - vertex.x, dy: p3.y - vertex.y)
        
        // Hitung dot product dari kedua vector
        let dot = v1.dx * v2.dx + v1.dy * v2.dy
        
        // Hitung magnitude (panjang) dari setiap vector
        let mag1 = sqrt(v1.dx * v1.dx + v1.dy * v1.dy)
        let mag2 = sqrt(v2.dx * v2.dx + v2.dy * v2.dy)
        
        // Hitung sudut menggunakan arccos dan konversi ke derajat
        let angle = acos(dot / (mag1 * mag2))
        return angle * 180 / .pi
    }
    
    // Fungsi untuk menghitung jarak antara dua titik
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx*dx + dy*dy)
    }
}

// MARK: - SwiftUI Camera Preview
// UIViewRepresentable memungkinkan kita menggunakan UIView di dalam SwiftUI
struct CameraPreview: UIViewRepresentable {
    @ObservedObject var viewModel: CameraViewModel
    
    // Fungsi yang dipanggil saat SwiftUI perlu membuat UIView
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        // Buat layer untuk menampilkan preview kamera
        let previewLayer = AVCaptureVideoPreviewLayer(session: viewModel.session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspectFill  // Fill seluruh area tanpa distorsi
        view.layer.addSublayer(previewLayer)
        
        // Tambahkan overlay view untuk menggambar skeleton pose
        let poseOverlayView = PoseOverlayView()
        poseOverlayView.frame = view.frame
        poseOverlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]  // Auto-resize saat rotasi
        poseOverlayView.viewModel = viewModel
        view.addSubview(poseOverlayView)
        
        // Setup observation untuk update pose secara real-time
        viewModel.$currentPoseObservation
            .receive(on: DispatchQueue.main)  // Pastikan update UI di main thread
            .sink { observation in
                poseOverlayView.poseObservation = observation
            }
            .store(in: &context.coordinator.cancellables)
        
        return view
    }
    
    // Fungsi yang dipanggil saat SwiftUI perlu update UIView (tidak digunakan di sini)
    func updateUIView(_ uiView: UIView, context: Context) {}
    
    // Buat coordinator untuk mengelola state dan observations
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    // Coordinator class untuk menyimpan Combine subscriptions
    class Coordinator {
        var cancellables = Set<AnyCancellable>()
    }
}

// MARK: - Pose Overlay View
// Custom UIView untuk menggambar skeleton pose di atas camera preview
class PoseOverlayView: UIView {
    
    // MARK: - Properties
    // Pose observation yang akan digambar
    var poseObservation: VNHumanBodyPoseObservation? {
        didSet {
            setNeedsDisplay()  // Trigger redraw saat pose berubah
        }
    }
    
    weak var viewModel: CameraViewModel?
    
    // MARK: - Pose Ideal untuk Referensi
    // Koordinat normalisasi (0-1) untuk pose ideal kuda-kuda di tengah layar
    let idealPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [
        .leftShoulder: CGPoint(x: 0.35, y: 0.8),
        .rightShoulder: CGPoint(x: 0.65, y: 0.8),
        .leftElbow: CGPoint(x: 0.3, y: 0.65),
        .rightElbow: CGPoint(x: 0.7, y: 0.65),
        .leftWrist: CGPoint(x: 0.25, y: 0.5),
        .rightWrist: CGPoint(x: 0.75, y: 0.5),
        .root: CGPoint(x: 0.5, y: 0.5),
        .leftHip: CGPoint(x: 0.4, y: 0.45),
        .rightHip: CGPoint(x: 0.6, y: 0.45),
        .leftKnee: CGPoint(x: 0.38, y: 0.25),
        .rightKnee: CGPoint(x: 0.62, y: 0.25),
        .leftAnkle: CGPoint(x: 0.36, y: 0.1),
        .rightAnkle: CGPoint(x: 0.64, y: 0.1)
    ]
    
    // Threshold untuk menentukan apakah joint sudah "match" dengan pose ideal
    let matchThreshold: CGFloat = 0.08 // 8% dari layar (bisa disesuaikan)
    
    // MARK: - Koneksi Skeleton
    // Definisi garis-garis yang menghubungkan joints untuk membentuk skeleton
    let skeletonConnections: [(VNHumanBodyPoseObservation.JointName, VNHumanBodyPoseObservation.JointName)] = [
        (.neck, .leftShoulder),
        (.neck, .rightShoulder),
        (.leftShoulder, .leftElbow),
        (.rightShoulder, .rightElbow),
        (.leftElbow, .leftWrist),
        (.rightElbow, .rightWrist),
        (.neck, .root),
        (.root, .leftHip),
        (.root, .rightHip),
        (.leftHip, .leftKnee),
        (.rightHip, .rightKnee),
        (.leftKnee, .leftAnkle),
        (.rightKnee, .rightAnkle)
    ]
    
    // MARK: - Initializers
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isOpaque = false          // View transparan
        self.backgroundColor = .clear   // Background transparan
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.isOpaque = false
        self.backgroundColor = .clear
    }
    
    // MARK: - Drawing
    // Fungsi utama untuk menggambar skeleton overlay
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.clear(rect)  // Bersihkan area gambar
        
        // Gambar skeleton ideal sebagai referensi (abu-abu transparan)
        drawSkeleton(context: context, 
                    pose: idealPose, 
                    color: UIColor.gray.withAlphaComponent(0.4), 
                    pointRadius: 0,     // Tidak gambar titik untuk ideal pose
                    isIdeal: true)
        
        // Gambar pose user jika ada
        if let observation = poseObservation {
            var userPose: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
            
            // Konversi koordinat Vision ke koordinat layar
            for joint in idealPose.keys {
                if let point = try? observation.recognizedPoint(joint) {
                    // Vision menggunakan koordinat Y terbalik, jadi perlu diflip
                    let flippedY = 1.0 - point.location.y
                    userPose[joint] = CGPoint(x: point.location.x, y: flippedY)
                }
            }
            
            // Gambar skeleton user dengan warna dinamis dan titik-titik joints
            drawSkeleton(context: context, 
                        pose: userPose, 
                        color: nil,        // Warna akan ditentukan dinamis
                        pointRadius: 7,    // Radius titik joint
                        isIdeal: false)
        }
    }
    
    // MARK: - Helper Drawing Function
    // Fungsi untuk menggambar skeleton (garis dan titik)
    private func drawSkeleton(context: CGContext, 
                            pose: [VNHumanBodyPoseObservation.JointName: CGPoint], 
                            color: UIColor?, 
                            pointRadius: CGFloat, 
                            isIdeal: Bool) {
        
        // MARK: - Gambar Garis Skeleton
        let lineColor = color ?? UIColor.green  // Default hijau jika tidak ada warna
        context.setStrokeColor(lineColor.cgColor)
        context.setLineWidth(isIdeal ? 4.0 : 3.0)  // Garis ideal lebih tebal
        
        // Gambar setiap koneksi dalam skeleton
        for (joint1, joint2) in skeletonConnections {
            guard let p1 = pose[joint1], let p2 = pose[joint2] else { continue }
            
            // Konversi koordinat normalisasi ke koordinat pixel layar
            let start = CGPoint(x: p1.x * bounds.width, y: p1.y * bounds.height)
            let end = CGPoint(x: p2.x * bounds.width, y: p2.y * bounds.height)
            
            // Gambar garis
            context.move(to: start)
            context.addLine(to: end)
            context.strokePath()
        }
        
        // MARK: - Gambar Titik Joint (hanya untuk user pose)
        if !isIdeal {
            for (joint, point) in pose {
                // Tentukan warna berdasarkan kedekatan dengan pose ideal
                var ptColor = UIColor.yellow  // Default kuning
                
                if let ideal = idealPose[joint] {
                    // Hitung jarak dari posisi ideal
                    let dist = hypot(point.x - ideal.x, point.y - ideal.y)
                    // Hijau jika dekat dengan ideal, merah jika jauh
                    ptColor = dist < matchThreshold ? .green : .red
                }
                
                // Gambar lingkaran untuk joint
                context.setFillColor(ptColor.cgColor)
                let circleRect = CGRect(
                    x: point.x * bounds.width - pointRadius, 
                    y: point.y * bounds.height - pointRadius, 
                    width: pointRadius * 2, 
                    height: pointRadius * 2
                )
                context.fillEllipse(in: circleRect)
            }
        }
    }
}

