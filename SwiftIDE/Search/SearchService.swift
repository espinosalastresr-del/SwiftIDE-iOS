import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let lineContent: String
    let range: Range<String.Index>
    let matchText: String
}

actor SearchService {
    func search(in text: String, query: String, caseSensitive: Bool = false) -> [SearchResult] {
        guard !query.isEmpty else { return [] }
        
        var results: [SearchResult] = []
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            var searchRange = line.startIndex..<line.endIndex
            while let range = line.range(of: query, options: options, range: searchRange) {
                results.append(SearchResult(
                    lineNumber: index + 1,
                    lineContent: line,
                    range: range,
                    matchText: String(line[range])
                ))
                searchRange = range.upperBound..<line.endIndex
            }
        }
        return results
    }
    
    func replace(in text: String, query: String, replacement: String, caseSensitive: Bool = false, replaceAll: Bool = false) -> String {
        guard !query.isEmpty else { return text }
        
        let options: String.CompareOptions = caseSensitive ? [] : [.caseInsensitive]
        
        if replaceAll {
            var result = text
            var searchStart = result.startIndex
            while searchStart < result.endIndex,
                  let range = result.range(of: query, options: options, range: searchStart..<result.endIndex) {
                result.replaceSubrange(range, with: replacement)
                searchStart = result.index(range.lowerBound, offsetBy: replacement.count)
            }
            return result
        } else {
            if let range = text.range(of: query, options: options) {
                var result = text
                result.replaceSubrange(range, with: replacement)
                return result
            }
            return text
        }
    }
}
