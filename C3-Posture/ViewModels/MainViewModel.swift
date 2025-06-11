import SwiftUI
import Combine

// MARK: - Main App ViewModel

class MainViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var currentView: AppView = .home
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Private Properties
    
    private let postureService: PostureServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(postureService: PostureServiceProtocol = PostureService.shared) {
        self.postureService = postureService
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    func navigateToSinglePoseTraining() {
        currentView = .singlePoseSelection
    }
    
    func navigateToSequentialTraining() {
        currentView = .sequentialTraining
    }
    
    func navigateToHome() {
        currentView = .home
    }
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Handle error display timing
        $showError
            .debounce(for: .seconds(3), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.clearError()
            }
            .store(in: &cancellables)
    }
}

// MARK: - App View Enum

enum AppView {
    case home
    case singlePoseSelection
    case singlePoseTraining
    case sequentialTraining
} 