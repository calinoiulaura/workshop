import UIKit

struct User: Identifiable, Codable, Sendable {
    @MainActor static var shared: User?

    let id: UUID
    var name: String

    init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
    }
}

actor LoginService {
    private var userCache = [User.ID: User]()

    func login() async -> User {
        // Simulate network latency:
        try! await Task.sleep(for: .seconds(1))

        let user = User(name: "John Appleseed")
        userCache[user.id] = user
        return user
    }
}

final class StorageService: Sendable {
    nonisolated(unsafe) private let userDefaults = UserDefaults.standard

    func store<T: Identifiable & Encodable>(_ model: T) throws {
        let data = try JSONEncoder().encode(model)
        userDefaults.set(data, forKey: "model-\(model.id)")
    }
}

class ProfileViewController: UIViewController {
    private var user: User?
    private let onLogin: (User) -> Void
    private let loginService = LoginService()
    private let storageService = StorageService()

    init(user: User? = .shared,
         onLogin: @escaping (User) -> Void = { User.shared = $0 }) {
        self.user = user
        self.onLogin = onLogin
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    private func login() {
        Task {
            let user = await loginService.login()
            self.user = user
            onLogin(user)
        }
    }

    private func saveUser() {
        guard let user else { return }

        Task.detached { [storageService] in
            try storageService.store(user)
        }
    }
}
