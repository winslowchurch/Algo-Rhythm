//
//  ContentView.swift
//  Algo-Rhythm
//
//  Created by Ruth Negate on 2/12/23.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var sceneDelegate: SceneDelegate
    @State private var connected = false
    @State private var paused = false
    // @State private var healthconnected = false
    @ObservedObject private var connectivityManager = WatchConnectivityManager.shared
    @State var allowQueueing = false
    @State var playlistSelected = false
    @State private var selection = "Select a Playlist"
    @State private var drawingWidth = false
    @State private var animationAmount: CGFloat = 1
    
    var body: some View {
        ZStack {
            Color(red: 223 / 255, green: 219 / 255, blue: 236 / 255).ignoresSafeArea()
            if (!connected) {
                Button(action: {
                    sceneDelegate.connect()
                    connected = true
                }) {
                    Text("Connect to Spotify").foregroundColor(.accentColor).padding().font(.title).background(.white).cornerRadius(40)
                }
     
            } else {
//                if (!healthconnected) {
//                    Button(action: {
//                        sceneDelegate.authorizeHealthKit()
//                        healthconnected = true
//                    }) {
//                        Text("Connect to HealthKit").foregroundColor(.accentColor).padding().font(.title).background(.white).cornerRadius(40)
//                    }
//                } else {
                    // LOADING SCREEN FOR PLAYLISTS
                    if sceneDelegate.playlists.count == 0 {
                        VStack(alignment: .leading) {
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.accentColor)
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color(.systemGray6))
                                    .frame(width: drawingWidth ? 250 : 0, alignment: .leading)
                                    .animation(.easeInOut(duration: 10).repeatForever(autoreverses: false), value: drawingWidth)
                            }
                            .frame(width: 250, height: 12)
                            .onAppear { drawingWidth.toggle() }
                            Text("Fetching playlists...").font(.title).foregroundColor(.white)
                        }
                    // SELCT A PLAYLIST
                    } else if playlistSelected == false {
                        let dict = sceneDelegate.getPlaylistDictionary()
                        VStack {
                            Picker("Select A Playlist", selection: $selection) {
                                let keys = Array(dict.keys)
                                ForEach(keys, id: \.self) {
                                    key in Text(dict[key] ?? "")
                                }
                            }
                            .pickerStyle(.menu).tint(.white).scaleEffect(2)
                            if (selection != "Select a Playlist") {
                                Button(action: {
                                    playlistSelected = true
                                    sceneDelegate.getTracks(playlistID: selection)
                                }) {
                                    Text("Submit").foregroundColor(.accentColor).padding().font(.title).background(.white).cornerRadius(40)
                                }
                            }
                        }
                    } else {
                        VStack {
                            // TOGGLE SWITCH
                            Toggle(isOn: $sceneDelegate.queueingAllowed, label: {
                                HStack {
                                    Image(systemName: "music.quarternote.3")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                    Text("Queue Songs")
                                        .font(.system(size:30))
                                        .bold()
                                        .foregroundColor(.white)
                                }
                            }).padding().frame(alignment: .top)
                            
                            HStack {
                                Image("pixelheart").resizable()
                                    .frame(width: 40, height: 50)
                                    .foregroundColor(.white)
                                    .scaleEffect(animationAmount)
                                    .animation(
                                        .linear(duration: 0.1)
                                        .delay(0.2)
                                        .repeatForever(autoreverses: true),
                                        value: animationAmount)
                                    .onAppear {
                                        animationAmount = 1.2
                                    }
                                Text(connectivityManager.bpmMessage ?? "0" + " BPM")
                                    .font(.system(size: 50, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            Text(sceneDelegate.trackName).foregroundColor(.white).font(.system(size: 25, weight: .semibold))
                            Spacer().frame(height:5)
                            Text(sceneDelegate.trackArtist).foregroundColor(.white).font(.system(size: 20, weight: .semibold))
                            // Filler image for now
                            Image(uiImage: sceneDelegate.image).resizable()
                                .scaledToFill()
                                .frame(width:330, height:330)
                                .cornerRadius(20)
                                .shadow(radius:10)
                            Spacer().frame(height: 20)
                            HStack {
                                Button(action: {
                                    sceneDelegate.appRemote.playerAPI?.skip(toPrevious: {(success, error) in if let error = error {
                                        print(error)
                                    }})
                                
                                }) {
                                    Image(systemName: "backward.circle.fill").font(.system(size: 50, weight: .bold)).background(.white).foregroundColor(.accentColor).cornerRadius(100)
                                }
                                if (!paused) {
                                    Button(action: {
                                        sceneDelegate.appRemote.playerAPI?.pause(nil)
                                        paused = true
                                    }) {
                                        Image(systemName: "pause.circle.fill").font(.system(size: 50, weight: .bold)).background(.white).foregroundColor(.accentColor).cornerRadius(100)
                                    }
                                } else {
                                    Button(action: {
                                        sceneDelegate.appRemote.playerAPI?.resume(nil)
                                        paused = false
                                    }) {
                                        Image(systemName: "play.circle.fill").font(.system(size: 50, weight: .bold)).background(.white).foregroundColor(.accentColor).cornerRadius(100)
                                    }
                                }
                                Button(action: {
                                    sceneDelegate.appRemote.playerAPI?.skip(toNext: {(success, error) in if let error = error {
                                        print(error)
                                    }})
                                }) {
                                    Image(systemName: "forward.circle.fill").font(.system(size: 50, weight: .bold)).background(.white).foregroundColor(.accentColor).cornerRadius(100)
                                }
                            }
                        }
                    
                }
            }
        }
    }
}


struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
