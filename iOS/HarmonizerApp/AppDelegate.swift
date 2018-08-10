/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Main entry point to the application.
*/

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: Properties
    
	var window: UIWindow?
    
    func applicationDidFinishLaunching(_ application: UIApplication) {
        UITableViewCell.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().separatorColor = UIColor.lightGray
        UITableViewHeaderFooterView.appearance().tintColor = UIColor.darkGray
        UILabel.appearance(whenContainedInInstancesOf: [UITableView.self]).textColor = UIColor.white
        UILabel.appearance(whenContainedInInstancesOf: [UITableView.self]).highlightedTextColor = UIColor.lightGray
        BaseView.appearance().backgroundColor = UIColor.clear
        UIPickerView.appearance().backgroundColor = UIColor.clear
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().backgroundColor = UIColor.darkGray
       // UINavigationBar.appearance().text
        
        
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        let isInitialized = defaults?.bool(forKey: "init")
        
        if (!isInitialized!)
        {
            defaults?.set(true,forKey: "showMidiKeyboard")
            defaults?.set(0, forKey: "presetIndex")
        }
        
    }
}
