//
//  MyFuzzView.swift
//  TestFuzz
//
//  Created by Андрій on 03.01.2025.
//

import SwiftUI

struct Matrix<T> {
    private(set) var array: [T] = []
    let width: Int
    let height: Int
    
    init(width: Int, height: Int, defElement: T) {
        self.array = Array(repeating: defElement, count: width * height)
        self.width = width
        self.height = height
    }
    
    subscript(row: Int, column: Int) -> T {
        get {
            return array[width * row + column]
        } set {
            array[width * row + column] = newValue
        }
    }
    
    func printMatrix() {
        for row in 0..<self.height {
            for column in 0..<self.width {
                print(array[width * row + column], terminator: "\t")
            }
            print()
        }
        print("\n")
    }
    
    func getSum() -> Int {
        assert (T.self == Int.self)
        return array.reduce(0) { partialResult, number in
            partialResult + (number as! Int)
        }
    }
}

extension String {
    func fuzzySearch(query: String) -> (Int, [String.Index]) {
        func setValue(top: Int, left: Int, diagonal: Int, currentIndex: (Int, Int)) -> Int {
            func getCharacter(at index: Int, for string: String) -> Character {
                let idx: String.Index = string.index(startIndex, offsetBy: index)
                assert (idx <= string.endIndex && idx >= string.startIndex)
                return string[idx]
            }
            var score = 0
            
            let match = 1
            let misMatch = -1
            let gap = -2
            
            let topValue = top + gap
            let leftValue = left + gap
            
            let diagonalMatch = getCharacter(at: currentIndex.0-1, for: query) == getCharacter(at: currentIndex.1-1, for: self)
            let diagonalValue = diagonal + (diagonalMatch ? match : misMatch)
            
            score = Swift.max(topValue, leftValue, diagonalValue, score)
            
            return score
        }
        
        var matrix = Matrix<Int>(width: self.count+1, height: query.count+1, defElement: 0)
        
        for row in 0..<matrix.height {
            for column in 0..<matrix.width {
                if row == 0 || column == 0 {
                    matrix[row, column] = 0
                    continue
                }
                matrix[row, column] = setValue(top: matrix[row-1, column], left: matrix[row, column-1], diagonal: matrix[row-1, column-1], currentIndex: (row, column))
            }
        }
        
        return (matrix.getSum(), self.getIndexesToHighlight(query: query))
    }
    
    func getIndexesToHighlight(query: String) -> [String.Index] {
        var result: [String.Index] = []
        var substring = self[...]
        for char in query {
            if let matchIndex = substring.firstIndex(of: char) {
                let idx = self.index(after: matchIndex)
                substring = self[idx...]
                result.append(matchIndex)
            }
        }
        return Array(result.sorted())
    }
}

struct File: Identifiable {
    let id: String = UUID().uuidString
    let content: String
    var score: Int
    var charMatchIndexes: [String.Index]
}


struct MyFuzzView: View {
    @State private var query: String = ""
    
    var resultFiles: [File] {
        var moddedFiles: [File] = files
            .compactMap { file in
                let (score, indexes) = file.lowercased().fuzzySearch(query: query.lowercased())
                guard score > 0 else { return nil }
                return File(content: file, score: score, charMatchIndexes: indexes)
            }
            .filter { file in
                var maxIntervalValue = 2
                let intArray = file.charMatchIndexes.map { index in
                    return file.content.distance(from: file.content.startIndex, to: index)
                }
                for (index, value) in intArray.enumerated() {
                    guard index + 1 < intArray.endIndex else { continue }
                    if intArray[index+1] != value + 1 {
                        maxIntervalValue -= 1
                    }
                }
                // MARK: - Removes matches with more than 2 gaps between parts
                // MARK: - Removes matches with less than 2 chars matched
                return maxIntervalValue >= 0 && file.charMatchIndexes.count > 0
            }
            .sorted { file1, file2 in
                // MARK: - Those matches that start with the capitalized letter should appear higher
                let isFile1Uppercase = file1.charMatchIndexes.first.map { file1.content[$0].isUppercase } ?? false
                let isFile2Uppercase = file2.charMatchIndexes.first.map { file2.content[$0].isUppercase } ?? false
                return isFile1Uppercase && !isFile2Uppercase
            }
            .sorted {
                let first = (Double($0.score) / Double($0.content.count))
                let second = (Double($1.score) / Double($1.content.count))
                return first > second
            }
            .sorted {
                return $0.charMatchIndexes.count > $1.charMatchIndexes.count
            }
        
        var maxMatchedCharsCount = 0
        
        for file in moddedFiles {
            if file.charMatchIndexes.count > maxMatchedCharsCount {
                maxMatchedCharsCount = file.charMatchIndexes.count
            }
        }

        moddedFiles = moddedFiles.filter { file in
            return (file.charMatchIndexes.count == maxMatchedCharsCount) /*&& !file.content.lowercased().contains(query.lowercased())*/
        }
//        
//        let containsArray: [File] = files.compactMap { string in
//            return string.lowercased().contains(query.lowercased()) ? File(content: string, score: 0, charMatchIndexes: []) : nil
//        }
//        moddedFiles.insert(contentsOf: containsArray, at: moddedFiles.startIndex)
        return moddedFiles
    }
    
    var body: some View {
        VStack {
            TextField("abc", text: $query)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .textFieldStyle(.roundedBorder)
            List(resultFiles) { file in
                let _ = print("Score: ", file.score, " for: ", file.content, "\n")
                highlight(string: file.content, indicies: file.charMatchIndexes)
            }
        }
    }
    
    private func highlight(string: String, indicies: [String.Index]) -> Text {
        var result = Text("")
        for i in string.indices {
            let char = Text(String(string[i]))
            if indicies.contains(i) {
                result = result + char.bold().foregroundStyle(.orange)
            } else {
                result = result + char
            }
        }
        
        return result
    }
}

#Preview {
    MyFuzzView()
}
