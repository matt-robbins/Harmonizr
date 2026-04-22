//
//  HarmonizerApp.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 4/21/26.
//

import SwiftUI


@main
struct HarmonizerApp: App {
    // @UIApplicationDelegateAdaptor private var appDelegate: AppDelegate
    var body: some Scene {
        WindowGroup {
            StoryboardViewController()
        }
    }
}

struct StoryboardViewController: UIViewControllerRepresentable {
    func updateUIViewController(_ uiViewController: UIViewControllerType, context: Context) {
        print("updateUIViewController")
    }
    
    func makeUIViewController(context: Context) -> some UIViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        let controller = storyboard.instantiateViewController(identifier: "main")
        return controller
    }
    
}
