//
//  AppDelegate.swift
//  Algo-Rhythm
//
//  Created by Ruth Negate on 2/13/23.
//

import Foundation

class AppDelegate: NSObject, UIApplicationDelegate {

  func application(
    _ application: UIApplication,
    configurationForConnecting connectingSceneSession: UISceneSession,
    options: UIScene.ConnectionOptions
  ) -> UISceneConfiguration {
    let sceneConfig = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
    sceneConfig.delegateClass = SceneDelegate.self
    return sceneConfig
  }
}
