import Foundation

//@MainActor
//func doSomework() async {
//    print("Doing some work on thread: \(Thread.isMainThread)")
//}
//
//final class Program {
//    @MainActor
//    func run() {
//        Task {
//            print("Is this task on main thread? \(Thread.isMainThread)")
//            
//            Task {
//                await doSomework()
//            }
//            
//            print("Is this task on main thread? \(Thread.isMainThread)")
//        }
//    }
//}

struct SearchViewModel {
    var music: [SearchResult]
    var movies: [SearchResult]
    var podcasts: [SearchResult]
}

actor SearchService {
    private var cache = [URL: [SearchResult]]()
    private var tasks = [URL: Task<[SearchResult], Error>]()
    
    func results(matching query: String, mediaType: MediaType?) async throws -> [SearchResult] {
        let url = URL.search(for: query, mediaType: mediaType)
        
        if let cachedResults = cache[url] {
            print("Used cached results for URL: \(url)")
            return cachedResults
        } else if let existingTask = tasks[url] {
            print("Reusing task for URL: \(url)")
            return try await existingTask.value
        }
        
        print("Starting new task for URL: \(url)")
        
        let task = Task {
            defer {
                tasks[url] = nil
            }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(SearchResult.Response.self, from: data)
            let results = response.results
            cache[url] = results
            
            return results
        }
        
        tasks[url] = task
        return try await task.value
    }
    
    func viewModel(forQuery query: String) async throws -> SearchViewModel {
//        let music = try await results(matching: query, mediaType: .music)
//        let movies = try await results(matching: query, mediaType: .movie)
//        let podcasts = try await results(matching: query, mediaType: .podcast)
//        return SearchViewModel(
//            music: music,
//            movies: movies,
//            podcasts: podcasts)
        
        async let music = results(matching: query, mediaType: .music)
        async let movies = results(matching: query, mediaType: .movie)
        async let podcasts = results(matching: query, mediaType: .podcast)
        return SearchViewModel(music: try await music, movies: try await movies, podcasts: try await podcasts)
    }
        
}

final class Program {
    func run() {
        Task {
            let service = SearchService()
            do {
                async let viewModelA = service.viewModel(forQuery: "Kelly Family")
                async let viewModelB = service.viewModel(forQuery: "Kelly Family")
                
                try await print("Music: \(viewModelA.music.count) Movies: \(viewModelA.movies.count) Podcasts: \(viewModelA.podcasts.count)")
                try await print("Music: \(viewModelB.music.count) Movies: \(viewModelB.movies.count) Podcasts: \(viewModelB.podcasts.count)")
                
                let viewModelC = try await service.viewModel(forQuery: "Kelly Family")
                print("Music: \(viewModelC.music.count) Movies: \(viewModelC.movies.count) Podcasts: \(viewModelC.podcasts.count)")
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
