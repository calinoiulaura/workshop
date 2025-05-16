import Foundation

struct SearchResult: Codable {
    enum CodingKeys: String, CodingKey {
        case name = "trackName"
    }

    var name: String
}

extension SearchResult {
    struct Response: Codable {
        var results: [SearchResult]
    }
}

enum MediaType: String {
    case movie
    case music
    case podcast
}

extension URL {
    static func search(for query: String, mediaType: MediaType?) -> Self {
        let query = query
            .replacingOccurrences(of: " ", with: "+")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)

        var components = URLComponents(string: "https://itunes.apple.com/search")!

        components.queryItems = [
            URLQueryItem(
                name: "term",
                value: query
            ),
            URLQueryItem(
                name: "media",
                value: mediaType?.rawValue ?? "all"
            )
        ]

        return components.url!
    }
}
