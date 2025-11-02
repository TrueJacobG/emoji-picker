//
//  Emoji.swift
//  emoji-picker
//
//  Created by Jakub Gradzewicz on 02/11/2025.
//


import Foundation

// 1. Define the Emoji data structure
// It must conform to Codable (to load from JSON)
// and Identifiable (to be used in SwiftUI lists/grids).
// Hashable is added so we can use id: \.self in the ForEach loop.
struct Emoji: Identifiable, Codable, Hashable {
    // Use UUID to give each emoji a unique ID for SwiftUI
    let id = UUID()
    let emoji: String
    let name: String
    
    // We need to tell the Codable protocol to only
    // look for 'emoji' and 'name' in the JSON.
    private enum CodingKeys: String, CodingKey {
        case emoji, name
    }
}

// 2. Create a class to load and hold the emoji data
class EmojiProvider {
    
    /**
     Loads and decodes the emoji JSON file from the app's main bundle.
     
     - Parameter filename: The name of the JSON file (without the .json extension).
     - Returns: An array of `Emoji` objects.
     
     This function will cause a fatal error (crash) if the file isn't found
     or cannot be decoded. This is often desired for essential app resources.
     */
    static func loadEmojis(from filename: String) -> [Emoji] {
        guard let url = Bundle.main.url(forResource: filename, withExtension: "json") else {
            fatalError("Could not find \(filename).json in the app bundle. Make sure it's added to the project and the 'Copy Bundle Resources' build phase.")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load data from \(filename).json.")
        }
        
        do {
            let decoder = JSONDecoder()
            let emojis = try decoder.decode([Emoji].self, from: data)
            return emojis
        } catch {
            fatalError("Could not decode \(filename).json: \(error)")
        }
    }
}
