import Foundation

class MusicSearchRanker {

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
    
    init() {}
    
    func sortAndFilterTracks(tracks: [SpotifyTrack], term: String) -> [SpotifyTrack] {
        let query = processQuery(term: term)

        let scoredTracks = tracks.enumerated().map { index, track in
            let score = calculateRelevanceScore(for: track, query: query, originalIndex: index, totalTracks: tracks.count)
            return (track: track, score: score)
        }

        let sortedScoredTracks = scoredTracks.sorted { $0.score > $1.score }

        return sortedScoredTracks.map { $0.track }
    }

    private func processQuery(term: String) -> ProcessedQuery {
        let tokens = tokenize(term)
        let tokenSet = Set(tokens)
        
        return ProcessedQuery(
            tokens: tokens,
            tokenSet: tokenSet
        )
    }

    private func calculateRelevanceScore(for track: SpotifyTrack, query: ProcessedQuery, originalIndex: Int, totalTracks: Int) -> Double {
        let trackNameTokens = tokenize(track.name)
        let artistNameTokens = tokenize(track.artistName)
        let albumNameTokens = tokenize(track.album.name)

        let titleScore = calculateFieldScore(query: query, fieldTokens: trackNameTokens)
        let artistScore = calculateFieldScore(query: query, fieldTokens: artistNameTokens)
        let albumScore = calculateFieldScore(query: query, fieldTokens: albumNameTokens)

        var textScore = (titleScore * titleWeight) +
                         (artistScore * artistWeight) +
                         (albumScore * albumWeight)
        
        if titleScore > 0 && artistScore > 0 {
            textScore += 1.0
        }
        
        if textScore == 0 {
            return 0
        }

        let titleWordCount = Double(trackNameTokens.count)
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
        
        let rankScore = (1.0 - (Double(originalIndex) / Double(totalTracks))) * originalRankWeight

        return textScore * (1.0 + popScore + rankScore)
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
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))\\b"
            result = result.replacingOccurrences(of: pattern, with: value, options: [.regularExpression, .caseInsensitive])
        }

        result = result.folding(options: .diacriticInsensitive, locale:.current)
        
        let allowedChars = CharacterSet.alphanumerics.union(.whitespaces)
        result = result.components(separatedBy: allowedChars.inverted).joined()

        let tokens = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        
        // Filter stop words, ignored words, and 4-digit years
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

