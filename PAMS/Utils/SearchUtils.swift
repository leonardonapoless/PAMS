import Foundation

// ranks search results
public class MusicSearchRanker {

    // MARK: - Config

    // words to ignore
    private let stopWords: Set<String> = ["a", "an", "and", "are", "as", "at", "be", "by", "for", "from", "has", "he", "in", "is", "it", "its", "of", "on", "that", "the", "to", "was", "were", "will", "with"]

    private let synonyms: [String: String] = [
        "you've": "you have",
        "ft": "featuring",
        "feat": "featuring"
    ]

    // lower scores
    private let negativeKeywords: [String: Double] = [
        "remix": 0.5,
        "cover": 0.2,
        "take": 0.6,
        "version": 0.4,
        "tribute": 0.3,
        "live": 0.1,
        "ao vivo": 0.0
    ]

    // MARK: - Weights

    // how important is title vs artist
    private let titleWeight: Double = 0.6
    private let artistWeight: Double = 0.3
    private let albumWeight: Double = 0.1

    // score for 1, 2, or 3 word matches
    private let unigramWeight: Double = 1.0       // 1 word
    private let bigramWeight: Double = 2.0        // 2 words
    private let trigramWeight: Double = 3.0       // 3 words
    private let fuzzyMatchWeight: Double = 0.5    // typos
    private let fuzzySimilarityThreshold: Double = 0.8

    // popularity weights
    // track streams matter more
    private let trackPopularityWeight: Double = 0.6  // dominant factor (streams)
    private let artistPopularityWeight: Double = 0.2  // secondary factor (fame)
    private let popularArtistBonus: Double = 0.1      // small extra nudge
    private let popularArtistThreshold: Int = 80

    // MARK: - Caching

    // cache for tokens
    private var tokenCache = [String: [String]]()

    // process query once
    private struct ProcessedQuery {
        let tokens: [String]
        let tokenSet: Set<String>
        let bigrams: Set<String>
        let trigrams: Set<String>
    }
    
    public init() {}
    
    public func clearCache() {
        tokenCache = [:]
    }

    // MARK: - Public API

    // main search function
    public func sortAndFilterTracks(tracks: [SpotifyTrack], term: String) -> [SpotifyTrack] {
        // process query
        let query = processQuery(term: term)

        // score tracks
        let scoredTracks = tracks.map { track in
            let score = calculateRelevanceScore(for: track, query: query)
            return (track: track, score: score)
        }

        // sort
        let sortedScoredTracks = scoredTracks.sorted { $0.score > $1.score }

        // return tracks
        return sortedScoredTracks.map { $0.track }
    }

    // MARK: - Scoring

    // process the search text
    private func processQuery(term: String) -> ProcessedQuery {
        let tokens = tokenize(term)
        let tokenSet = Set(tokens)
        let bigrams = ngrams(tokens: tokens, size: 2)
        let trigrams = ngrams(tokens: tokens, size: 3)
        
        return ProcessedQuery(
            tokens: tokens,
            tokenSet: tokenSet,
            bigrams: bigrams,
            trigrams: trigrams
        )
    }

    // score for one track
    private func calculateRelevanceScore(for track: SpotifyTrack, query: ProcessedQuery) -> Double {
        
        // CALCULATE TEXT SCORE
        
        // get tokens
        let trackNameTokens = getCachedTokens(for: track.name)
        let artistNameTokens = getCachedTokens(for: track.artistName)
        let albumNameTokens = getCachedTokens(for: track.album.name)

        // score fields
        let titleScore = calculateFieldScore(query: query, fieldTokens: trackNameTokens)
        let artistScore = calculateFieldScore(query: query, fieldTokens: artistNameTokens)
        let albumScore = calculateFieldScore(query: query, fieldTokens: albumNameTokens)

        // add scores
        var textScore = (titleScore * titleWeight) +
                         (artistScore * artistWeight) +
                         (albumScore * albumWeight)
        
        // if text score is 0, just stop
        if textScore == 0 {
            return 0
        }

        // apply penalties to the text score
        
        // length penalty
        let titleWordCount = Double(trackNameTokens.count)
        let queryWordCount = Double(query.tokens.count)
        
        if titleWordCount > queryWordCount {
            let diff = titleWordCount - queryWordCount // simple count of extra words
            let penalty = pow(0.9, diff) // 10% penalty per extra word
            textScore *= penalty
        }
        
        // negative keyword penalties
        let trackTokenSet = Set(trackNameTokens)
        for (keyword, penalty) in negativeKeywords {
            // if track has "remix"
            if trackTokenSet.contains(keyword) {
                // and user didn't search for "remix"
                if !query.tokenSet.contains(keyword) {
                    // apply penalty
                    textScore *= penalty
                }
            }
        }

        // CALCULATE POPULARITY SCORE
        
        var popScore = 0.0
        // (using new track-dominant weights)
        if let trackPopularity = track.popularity {
            popScore += (Double(trackPopularity) / 100.0) * trackPopularityWeight
        }
        if let artistPopularity = track.artists.first?.popularity {
            popScore += (Double(artistPopularity) / 100.0) * artistPopularityWeight
            if artistPopularity > popularArtistThreshold {
                popScore += popularArtistBonus // bonus for stars
            }
        }

        // combine scores
        let totalScore = textScore * (1.0 + popScore)

        return totalScore
    }

    // score one field (title, artist, etc)
    private func calculateFieldScore(query: ProcessedQuery, fieldTokens: [String]) -> Double {
        var score = 0.0
        let fieldTokenSet = Set(fieldTokens)

        // exact matches
        let exactUnigramMatches = query.tokenSet.intersection(fieldTokenSet)
        score += Double(exactUnigramMatches.count) * unigramWeight

        // typo matches
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

        // 3. phrase matches
        let fieldBigrams = ngrams(tokens: fieldTokens, size: 2)
        score += Double(query.bigrams.intersection(fieldBigrams).count) * bigramWeight
        
        let fieldTrigrams = ngrams(tokens: fieldTokens, size: 3)
        score += Double(query.trigrams.intersection(fieldTrigrams).count) * trigramWeight

        return score
    }

    // MARK: - Text Processing

    // get tokens from cache
    private func getCachedTokens(for string: String) -> [String] {
        if let cached = tokenCache[string] {
            return cached
        }
        let tokens = tokenize(string)
        tokenCache[string] = tokens
        return tokens
    }

    // clean up text
    private func tokenize(_ string: String) -> [String] {
        var result = string.lowercased()

        // synonyms
        for (key, value) in synonyms {
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: key))\\b"
            result = result.replacingOccurrences(of: pattern, with: value, options: [.regularExpression, .caseInsensitive])
        }

        // café -> cafe
        result = result.folding(options: .diacriticInsensitive, locale:.current)
        
        // remove punctuation
        let allowedChars = CharacterSet.alphanumerics.union(.whitespaces)
        result = result.components(separatedBy: allowedChars.inverted).joined()

        // split words, remove stop words
        let tokens = result.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let filteredTokens = tokens.filter { !stopWords.contains($0) }

        // if filtered everything out (e.g., "The The"),
        // just use the original tokens
        if filteredTokens.isEmpty && !tokens.isEmpty {
            return tokens
        }

        return filteredTokens
    }

    // makes 2-word or 3-word phrases
    private func ngrams(tokens: [String], size: Int) -> Set<String> {
        var ngrams = Set<String>()
        guard tokens.count >= size else { return ngrams }

        for i in 0...(tokens.count - size) {
            let ngramSlice = tokens[i..<(i + size)]
            ngrams.insert(ngramSlice.joined(separator: " "))
        }
        return ngrams
    }

    // MARK: - Algorithms

    // for typo check
    // (faster with char arrays)
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
                    currentRow[j - 1] + 1, // insertion
                    previousRow[j] + 1,   // deletion
                    previousRow[j - 1] + cost // substitution
                )
            }
            previousRow = currentRow
        }
        return previousRow[bCount]
    }
}

