import Foundation
import RegexBuilder

actor MusicSearchRanker {

    private let stopWords: Set<String> = ["a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "has", "he", "in", "is", "it", "its", "of", "on", "that", "the", "to", "was", "were", "will", "with"]

    private let synonyms: [String: String] = [
        "you've": "you have",
        "ft": "featuring",
        "feat": "featuring"
    ]

    private let ignoredWords: Set<String> = ["remastered", "remaster", "stereo", "mono", "deluxe", "edition", "expanded", "anniversary"]

    private let titleWeight: Double = 0.5
    private let artistWeight: Double = 0.5
    private let albumWeight: Double = 0.2

    private let unigramWeight: Double = 1.0
    private let fuzzyMatchWeight: Double = 0.5
    private let fuzzySimilarityThreshold: Double = 0.8

    private let trackPopularityWeight: Double = 0.5
    private let artistPopularityWeight: Double = 3.0
    private let originalRankWeight: Double = 5.0
    private let popularArtistBonus: Double = 1.0
    private let popularArtistThreshold: Int = 50

    private struct ProcessedQuery {
        let tokens: [String]
        let tokenSet: Set<String>
    }
    
    private let relevanceThreshold: Double = 1.0
    
    init() {}
    
    struct RankedItem: Sendable {
        let item: ItemType
        let score: Double
        
        enum ItemType: Sendable {
            case track(SpotifyTrack)
            case album(SpotifyAlbum)
        }
    }

    struct SearchResult: Sendable {
        let items: [RankedItem]
        let hasRelevantResults: Bool
    }
    
    func sortAndFilter(tracks: [SpotifyTrack], albums: [SpotifyAlbum], term: String) -> SearchResult {
        let query = processQuery(term: term)

        var rankedItems: [RankedItem] = []

        for (index, track) in tracks.enumerated() {
            let score = calculateTrackScore(track, query: query, originalIndex: index, totalItems: tracks.count)
            if score > 0 {
                rankedItems.append(RankedItem(item: .track(track), score: score))
            }
        }

        for (index, album) in albums.enumerated() {
            let score = calculateAlbumScore(album, query: query, originalIndex: index, totalItems: albums.count)
            if score > 0 {
                rankedItems.append(RankedItem(item: .album(album), score: score))
            }
        }

        let sorted = rankedItems.sorted { $0.score > $1.score }
        let bestScore = sorted.first?.score ?? 0
        
        return SearchResult(
            items: sorted,
            hasRelevantResults: bestScore >= relevanceThreshold
        )
    }

    private func processQuery(term: String) -> ProcessedQuery {
        let tokens = tokenize(term)
        let tokenSet = Set(tokens)
        
        return ProcessedQuery(
            tokens: tokens,
            tokenSet: tokenSet
        )
    }

    private func calculateTrackScore(_ track: SpotifyTrack, query: ProcessedQuery, originalIndex: Int, totalItems: Int) -> Double {
        let titleTokens = tokenize(track.name)
        let artistTokens = tokenize(track.artists.map { $0.name }.joined(separator: ", ")) // Avoid artistName if MainActor
        let albumTokens = tokenize(track.album.name)

        let titleScore = calculateFieldScore(query: query, fieldTokens: titleTokens)
        let artistScore = calculateFieldScore(query: query, fieldTokens: artistTokens)
        let albumScore = calculateFieldScore(query: query, fieldTokens: albumTokens)

        var textScore = (titleScore * titleWeight) +
                         (artistScore * artistWeight) +
                         (albumScore * albumWeight)

        if titleScore > 0 && artistScore > 0 {
            textScore += 1.0
        }
        
        if textScore == 0 { return 0 }
        
        let titleWordCount = Double(titleTokens.count)
        let queryWordCount = Double(query.tokens.count)
        if titleWordCount > queryWordCount {
            let diff = titleWordCount - queryWordCount
            let penalty = pow(0.9, diff)
            textScore *= penalty
        }
        
        var popScore = 0.0
        if let trackPopularity = track.popularity {
            popScore += (Double(trackPopularity) / 100.0) * trackPopularityWeight
        }
        if let artistPopularity = track.artists.first?.popularity {
            popScore += (Double(artistPopularity) / 100.0) * artistPopularityWeight
            if artistPopularity > popularArtistThreshold {
                popScore += popularArtistBonus
            }
        }
        let rankScore = (1.0 - (Double(originalIndex) / Double(totalItems))) * originalRankWeight

        return textScore * (1.0 + popScore + rankScore)
    }

    private func calculateAlbumScore(_ album: SpotifyAlbum, query: ProcessedQuery, originalIndex: Int, totalItems: Int) -> Double {
        let titleTokens = tokenize(album.name)
        let artistTokens = tokenize(album.artists.map { $0.name }.joined(separator: ", ")) // Avoid artistName if MainActor
        
        let titleScore = calculateFieldScore(query: query, fieldTokens: titleTokens)
        let artistScore = calculateFieldScore(query: query, fieldTokens: artistTokens)
        
        
        var textScore = (titleScore * 0.7) + (artistScore * 0.3)
        
        if titleScore > 0 && artistScore > 0 {
            textScore += 1.2 
        }
        
        if textScore == 0 { return 0 }
        
        let titleWordCount = Double(titleTokens.count)
        let queryWordCount = Double(query.tokens.count)
        if titleWordCount > queryWordCount {
             let diff = titleWordCount - queryWordCount
             let penalty = pow(0.85, diff) 
             textScore *= penalty
        }
        
        let albumEfficiencyBonus = 0.5
        let rankScore = (1.0 - (Double(originalIndex) / Double(totalItems))) * originalRankWeight

        return textScore * (1.0 + albumEfficiencyBonus + rankScore)
    }

    private func calculateFieldScore(query: ProcessedQuery, fieldTokens: [String]) -> Double {
        var score = 0.0
        let fieldTokenSet = Set(fieldTokens)

        let exactUnigramMatches = query.tokenSet.intersection(fieldTokenSet)
        score += Double(exactUnigramMatches.count) * unigramWeight

        let fuzzyQueryTokens = query.tokenSet.subtracting(exactUnigramMatches)
        let fuzzyFieldTokens = fieldTokenSet.subtracting(exactUnigramMatches)

        for queryToken in fuzzyQueryTokens {
            var bestSimilarity = 0.0
            for fieldToken in fuzzyFieldTokens {
                let distance = levenshteinDistance(a: queryToken, b: fieldToken)
                let maxLen = Double(max(queryToken.count, fieldToken.count))
                if maxLen == 0 { continue }
                
                let similarity = 1.0 - (Double(distance) / maxLen)
                
                if similarity > bestSimilarity {
                    bestSimilarity = similarity
                }
            }
            
            if bestSimilarity > fuzzySimilarityThreshold {
                score += bestSimilarity * fuzzyMatchWeight
            }
        }

        return score
    }

    private func tokenize(_ string: String) -> [String] {
        var result = string.lowercased()

        for (key, value) in synonyms {
            let regex = Regex {
                Anchor.wordBoundary
                key
                Anchor.wordBoundary
            }.ignoresCase()
            
            result = result.replacing(regex, with: value)
        }

        result = result.folding(options: .diacriticInsensitive, locale:.current)
        
        let allowedChars = CharacterSet.alphanumerics.union(.whitespaces)
        result = result.components(separatedBy: allowedChars.inverted).joined()

        let tokens = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        let filteredTokens = tokens.filter { token in
            if stopWords.contains(token) { return false }
            if ignoredWords.contains(token) { return false }
            if token.range(of: #"^\d{4}$"#, options: .regularExpression) != nil { return false }
            return true
        }

        if filteredTokens.isEmpty && !tokens.isEmpty {
            return tokens
        }

        return filteredTokens
    }

    private func ngrams(tokens: [String], size: Int) -> Set<String> {
        var ngrams = Set<String>()
        guard tokens.count >= size else { return ngrams }

        for i in 0...(tokens.count - size) {
            let ngramSlice = tokens[i..<(i + size)]
            ngrams.insert(ngramSlice.joined(separator: " "))
        }
        return ngrams
    }

    private func levenshteinDistance(a: String, b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        let aCount = aChars.count
        let bCount = bChars.count

        if aCount == 0 { return bCount }
        if bCount == 0 { return aCount }

        var previousRow = [Int](0...bCount)
        var currentRow = [Int](repeating: 0, count: bCount + 1)

        for i in 1...aCount {
            currentRow[0] = i
            for j in 1...bCount {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                
                currentRow[j] = min(
                    currentRow[j - 1] + 1,
                    previousRow[j] + 1,
                    previousRow[j - 1] + cost
                )
            }
            previousRow = currentRow
        }
        return previousRow[bCount]
    }
}