//
//  JSONDecoders.swift
//  Algo-Rhythm
//
//  Created by Ruth Negate on 2/20/23.
//

import Foundation

struct PlaylistsResponse: Codable {
    let total: Int
    let items: [PlaylistItem]
}

struct PlaylistItem: Codable {
    let id, name: String
}

struct TracksResponse: Codable {
    let total: Int
    let items: [TrackItem]
}

struct TrackItem: Codable {
    let track: Track?
}
struct Track: Codable {
    let id, uri: String?
}

struct AudioResponse: Decodable {
    let energy: Float?
    let loudness: Float?
    let tempo: Float?
}
