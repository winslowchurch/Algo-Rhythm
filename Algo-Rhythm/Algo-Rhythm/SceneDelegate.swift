//
//  SceneDelegate.swift
//  Algo-Rhythm
//
//  Created by Ruth Negate on 2/14/23.
//

import Foundation

import UIKit
import HealthKit
import Regressor

import DequeModule

class SceneDelegate: NSObject, UIWindowSceneDelegate, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate, SPTSessionManagerDelegate, ObservableObject {
    
    let SpotifyClientID = "5a5286f0bb514df0b4803788eb97245d"
    let SpotifyRedirectURL = URL(string: "algorhythm://spotify-login-callback")!
    lazy var configuration = SPTConfiguration(clientID: SpotifyClientID,
                                             redirectURL: SpotifyRedirectURL)
    var accessToken = ""
    let playURI = ""
    var previousPlayerState: SPTAppRemotePlayerState?
    let scopes: SPTScope = [.userReadEmail, .userReadPrivate, .userReadPlaybackState, .userModifyPlaybackState, .userReadCurrentlyPlaying, .streaming, .appRemoteControl, .playlistReadCollaborative, .playlistModifyPublic, .playlistReadPrivate, .playlistModifyPrivate, .userLibraryModify, .userLibraryRead, .userTopRead, .userReadPlaybackState, .userReadCurrentlyPlaying, .userFollowRead, .userFollowModify]
    
    // Spotify iOS API Reference: https://spotify.github.io/ios-sdk/html/
    // Spotify Web API Reference: https://developer.spotify.com/documentation/web-api/reference/#/
    //var tracks: [String: [Float]] = [:]
    var restTracks: [String] = [] // Tracks with energy score of 0 - 0.32. If user's BPM is <100, play from here.
    var lightTracks: [String] = [] // Tracks with energy score of 0.32 - 0.52. If user's BPM is 100-124, play from here.
    var moderateTracks: [String] = [] // Tracks with energy score of 0.52 - 0.72. If user's BPM is 125-149, play from here.
    var intenseTracks: [String] = [] // Tracks with energy score of 0.72 - 1. If user's BPM is >=150, play from here.
    //var storedBPM: [Int] = [] //store user heart rate from the last x seconds to make a predictor <- maybe there are privacy concerns here and we can deal with storage issues later
    
    var storedBPM: Deque<Int> = []//store user heart rate with a deque, for faster performance
    
    @Published var playlists: [PlaylistItem] = []
    
    
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else {
            return
        }
        
        self.sessionManager.application(UIApplication.shared, open: url, options: [:])
    }
    
    lazy var sessionManager: SPTSessionManager = {
         if let tokenSwapURL = URL(string: "https://algorhythm-spotify-authentication-token.glitch.me/api/token"),
            let tokenRefreshURL = URL(string: "https://algorhythm-spotify-authentication-token.glitch.me/api/refresh_token") {
           self.configuration.tokenSwapURL = tokenSwapURL
           self.configuration.tokenRefreshURL = tokenRefreshURL
           self.configuration.playURI = ""
         }
         let manager = SPTSessionManager(configuration: self.configuration, delegate: self)
         return manager
       }()
    

    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        accessToken = session.accessToken
        appRemote.connectionParameters.accessToken = session.accessToken
        // Request 50 of user's saved tracks
        let url = URL(string: "https://api.spotify.com/v1/me/playlists?limit=50")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print(error)
            } else if let data = data {
                DispatchQueue.main.async {
                    do {
                        let res = try JSONDecoder().decode(PlaylistsResponse.self, from: data)
                        self.playlists = res.items
                    } catch let error {
                        print(error)
                    }
                }
            } else {
                print("Unexpected Error")
            }
        }
        task.resume()
        appRemote.connect()
    }
    
    func getTracks(playlistID: String) {
        let url = URL(string: "https://api.spotify.com/v1/playlists/" + playlistID + "/tracks?limit=50")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
            if let error = error {
                print(error)
            } else if let data = data {
                do {
                    let res = try JSONDecoder().decode(TracksResponse.self, from: data)
                    for item in res.items {
                        let trackID = item.track?.id
                        let trackURI = item.track?.uri
                        guard let apiURL = URL(string: "https://api.spotify.com/v1/audio-features/" + trackID!) else {  return }
                        var request2 = URLRequest(url: apiURL)
                        request2.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
                        request2.httpMethod = "GET"
                        let task = URLSession.shared.dataTask(with: request2) { data, response, error in
                            if let error = error {
                                print(error)
                            } else if let data = data {
                                do {
                                    let audioInfo = try JSONDecoder().decode(AudioResponse.self, from: data)
                                    let energy = audioInfo.energy ?? 0
                                    if energy < 0.32 {
                                        self.restTracks.append(trackURI!)
                                    } else if energy < 0.52 {
                                        self.lightTracks.append(trackURI!)
                                    } else if energy < 0.72 {
                                        self.moderateTracks.append(trackURI!)
                                    } else {
                                        self.intenseTracks.append(trackURI!)
                                    }
//                                    self.tracks[trackURI!] = [audioInfo.energy ?? 0, audioInfo.loudness ?? 0, audioInfo.tempo ?? 0]
                                } catch let error {
                                    print(error)
                                }
                            } else {
                                print("Unexpected Error")
                            }
                        }
                        task.resume()
                    }
                } catch let error {
                    print(error)
                }
            } else {
                print("Unexpected Error")
            }
        }
        task.resume()
    }
    
    @Published var image = UIImage()
    @Published var trackName: String = ""
    @Published var trackArtist: String = ""
    
    func getTrackImage(for track: SPTAppRemoteTrack) {
            appRemote.imageAPI?.fetchImage(forItem: track, with: CGSize.zero, callback: { [weak self] (image, error) in
                if let error = error {
                    print(error)
                } else if let image = image as? UIImage {
                    self?.image = image
                }
            })
        }
    
    // Maps playlistID to playlistName
    func getPlaylistDictionary() -> [String: String] {
        var playlistDictionary: [String: String] = [:]
        playlistDictionary["Select a Playlist"] = "Select a Playlist"
        self.playlists.forEach {
            playlist in playlistDictionary[playlist.id] = playlist.name
        }
        return playlistDictionary
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print(error)
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        print("renewed")
    }
    
    let healthStore = HKHealthStore()
    
    func authorizeHealthKit() {
        let read = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!])
        let share = Set([HKObjectType.quantityType(forIdentifier: .heartRate)!])
        healthStore.requestAuthorization(toShare: share, read: read) {(chk, error) in
            if(chk) {
                print("perms grnated")
            }
        }
    }

    func latestHeartRate() {
        guard let sampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to:Date())
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit:
                                    Int(HKObjectQueryNoLimit), sortDescriptors: [sortDescriptor]) { (sample, result, error) in
            guard error == nil else {
                return
            }
            let data = result![0] as! HKQuantitySample
            let unit = HKUnit(from: "count/min")
            let latestHr = data.quantity.doubleValue(for: unit)
            print("Latest HR\(latestHr) BPM")
        }
        healthStore.execute(query)
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
      print("disconnected")
    }
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
      print("failed")
    }
    
    lazy var appRemote: SPTAppRemote = {
      let appRemote = SPTAppRemote(configuration: self.configuration, logLevel: .debug)
      appRemote.delegate = self
      return appRemote
    }()
    
    func connect() {
        self.sessionManager.initiateSession(with: scopes, options: .default)
        DispatchQueue.global(qos: .userInitiated).async {
        while(true) {
            sleep(1)
            let heartBeat = Int(WatchConnectivityManager.shared.bpmMessage ?? "0") ?? 0
            if self.storedBPM.count < 30 {
                self.storedBPM.append(heartBeat)
            } else {
                //self.storedBPM.removeFirst() array implementation
                self.storedBPM.popFirst() //only store the info for the last 30 seconds to make running the regression more tractable
                self.storedBPM.append(heartBeat)
            }
            print(self.storedBPM)
            let predicted_bpm = self.predict_bpm()
            print(predicted_bpm)
        }
    }
}
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        // Connection was successful, you can begin issuing commands
        self.appRemote.playerAPI?.delegate = self
        self.appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                debugPrint(error.localizedDescription)
            }
        })
    }
    typealias MyPoint = BaseRegressor<Double>.Point
    func predict_bpm() -> Int {
        
        var points: [BaseRegressor<Double>.Point] = []
        for (index, heartrate) in self.storedBPM.enumerated() {
            let point = MyPoint(x:Double(index), y: Double(heartrate)) //index is the time
            points.append(point)
        }
        
        let lr = LinearRegressor(points: points)!
        var predicted_bpm = lr.yRegression(x:45) //predict heart rate 15 seconds later
        if predicted_bpm.isNaN{ //regression returns Nan if every value in the deque is the same
            predicted_bpm = Double(self.storedBPM[0])
        }
        return Int(predicted_bpm)
    }
    
    func findTrack(bpm: Int, playerState: SPTAppRemotePlayerState) {
        let bpm = predict_bpm()
        previousPlayerState = nil
        if bpm < 100 {
            if restTracks.count > 0 {
                let randomInt = Int.random(in: 0..<restTracks.count)
                appRemote.playerAPI?.play(restTracks[randomInt], asRadio: false, callback: {(success, error) in
                    if let error = error {
                    print(error)
                }})
            } else {
                updateView(playerState: playerState)
            }
        } else if bpm < 125 {
            if lightTracks.count > 0 {
                let randomInt = Int.random(in: 0..<lightTracks.count)
                appRemote.playerAPI?.play(lightTracks[randomInt], asRadio: false, callback: {(success, error) in
                    if let error = error {
                    print(error)
                }})
            } else {
                updateView(playerState: playerState)
            }
        } else if bpm < 150 {
            if moderateTracks.count > 0 {
                let randomInt = Int.random(in: 0..<moderateTracks.count)
                appRemote.playerAPI?.play(moderateTracks[randomInt], asRadio: false, callback: {(success, error) in if let error = error {
                    print(error)
                }})
            } else {
                updateView(playerState: playerState)
            }
        } else {
            if intenseTracks.count > 0 {
                let randomInt = Int.random(in: 0..<intenseTracks.count)
                appRemote.playerAPI?.play(intenseTracks[randomInt], asRadio: false, callback: {(success, error) in
                    if let error = error {
                    print(error)
                }})
            } else {
                updateView(playerState: playerState)
            }
        }
    }
    
    func updateView(playerState: SPTAppRemotePlayerState) {
        trackName = playerState.track.name
        trackArtist = playerState.track.artist.name
        getTrackImage(for: playerState.track)
        previousPlayerState = playerState
    }
    
    @Published var queueingAllowed = true

    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        if previousPlayerState == nil {
            updateView(playerState: playerState)
        } else if previousPlayerState?.track.uri != playerState.track.uri {
            print("Track Change")
            if queueingAllowed {
                let heartBeat = Int(WatchConnectivityManager.shared.bpmMessage ?? "0") ?? 0
                self.findTrack(bpm: heartBeat, playerState: playerState)
            } else {
                updateView(playerState: playerState)
            }
            
        }
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
      if let _ = self.appRemote.connectionParameters.accessToken {
        self.appRemote.connect()
      }
        }

    func sceneWillResignActive(_ scene: UIScene) {
      if self.appRemote.isConnected {
        self.appRemote.disconnect()
      }
    }
}


