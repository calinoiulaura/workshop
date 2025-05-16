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
        
    func resultSequenceSequencial(forQueries queries: [String], mediaType: MediaType?) async throws -> AsyncThrowingStream<BatchResults, Error> {
        AsyncThrowingStream { continuation in
            Task {
                for query in queries {
                    do {
                        let results = try await self.results(matching: query, mediaType: mediaType)
                        let batch = BatchResults(query: query, results: results)
                        continuation.yield(batch)
                    } catch {
                        return continuation.finish(throwing: error)
                    }
                }
                continuation.finish()
            }
        }
    }
    
    func resultSequenceConccurent(forQueries queries: [String], mediaType: MediaType?) async throws -> AsyncThrowingStream<BatchResults, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    try await withThrowingTaskGroup(of: BatchResults.self) { group in
                        for query in queries {
                            group.addTask {
                                let results = try await self.results(matching: query, mediaType: mediaType)
                                return BatchResults(query: query, results: results)
                            }
                        }
                        
                        for try await batch in group {
                            continuation.yield(batch)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    func conccurentWithSequencial(forQueries queries: [String], mediaType: MediaType?) async throws -> AsyncThrowingStream<BatchResults, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let tasks = queries.map { query in
                    Task {
                        try await results(matching: query, mediaType: mediaType)
                    }
                }
                
                for (query, task) in zip(queries, tasks) {
                    do {
                        let results = try await task.value
                        let batch = BatchResults(query: query, results: results)
                        continuation.yield(batch)
                    } catch {
                        return continuation.finish(throwing: error)
                    }
                }
                
                continuation.finish()
            }
        }
    }
}
    
    struct BatchResults {
        var query: String
        var results: [SearchResult]
    }

final class Program {
    func run() {
        Task {
            let service = SearchService()
//            do {
//                async let viewModelA = service.viewModel(forQuery: "Kelly Family")
//                async let viewModelB = service.viewModel(forQuery: "Kelly Family")
//                
//                try await print("Music: \(viewModelA.music.count) Movies: \(viewModelA.movies.count) Podcasts: \(viewModelA.podcasts.count)")
//                try await print("Music: \(viewModelB.music.count) Movies: \(viewModelB.movies.count) Podcasts: \(viewModelB.podcasts.count)")
//                
//                let viewModelC = try await service.viewModel(forQuery: "Kelly Family")
//                print("Music: \(viewModelC.music.count) Movies: \(viewModelC.movies.count) Podcasts: \(viewModelC.podcasts.count)")
//            } catch {
//                print("Error: \(error)")
//            }
            
            do {
                for try await batch in try await service.resultSequenceSequencial(forQueries: ["Mettalica", "Star Wars", "Queen", "Friends"], mediaType: .movie) {
                    print("Query: \(batch.query) Results: \(batch.results.count)")
                }
            } catch {
                print("Error: \(error)")
            }
        }
    }
}
