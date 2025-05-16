import Foundation

protocol Loadable {
    associatedtype Output
    func load() async -> Output
}

final class RandomNumberLoader: Loadable, Sendable {
    private let generator: @Sendable () -> Int = { .random(in: 0..<Int.max) }

    func load() async -> Int {
        generator()
    }

    func storeLoadedNumber() {
        Task {
            let number = await load()
            UserDefaults.standard.set(number, forKey: "number")
        }
    }
}

@MainActor final class TextViewModel: Loadable {
    @Published private(set) var text = ""

    func load() async -> String {
        let text = await Task.detached {
            "Hello, world!"
        }.value
        
        self.text = text
        return text
    }
}
