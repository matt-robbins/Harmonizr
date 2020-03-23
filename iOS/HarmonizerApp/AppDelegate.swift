/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	Main entry point to the application.
*/

import UIKit

class TouchWindow: UIWindow {
    
    var points = [CALayer]()
    var tsize: CGFloat = 60
    var count = 0
    let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        createLayers()
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        createLayers()
    }
    
    private func createLayers()
    {
        for _ in 0...9
        {
            let point = CALayer()
            point.frame = CGRect(x: 0, y: 0, width: tsize, height: tsize)
            point.cornerRadius = CGFloat(tsize)/2.0
            point.backgroundColor = UIColor.white.cgColor
            point.shadowColor = UIColor.white.cgColor
            point.borderColor = UIColor.gray.cgColor
            point.borderWidth = 1
            point.shadowOffset = CGSize()
            point.shadowRadius = CGFloat(tsize)/2.0
            point.shadowOpacity = 1.0
            point.opacity = 0.5
            point.setValue(nil, forKey: "touch")
            points.append(point)
            //layer.addSublayer(point)
        }
    }
    
    override public func sendEvent(_ event: UIEvent) {
        let touches = event.allTouches
        let key = "touch"
        
        super.sendEvent(event)
        
        let touch = defaults?.bool(forKey: "showTouch")
        
        if ((touch == nil || touch == false) && count == 0)
        {
            return
        }
        
        for touch in touches! {
            let loc = touch.location(in: self)
            
            switch touch.phase {
            case .began:

                for p in points {
                    if p.value(forKey: key) == nil
                    {
                        p.setValue(touch, forKey: key)
                        CATransaction.begin()
                        CATransaction.setDisableActions(true)
                        
                        layer.addSublayer(p)
                        p.frame = CGRect(x: loc.x - tsize / 2, y: loc.y - tsize / 2, width: CGFloat(tsize), height: CGFloat(tsize))
                        
                        CATransaction.commit()
                        
                        p.opacity = 0.8
                        count+=1
                        break
                    }
                }
                
                
                break
            case .moved:
                CATransaction.begin()
                CATransaction.setDisableActions(true)
                
                for p in points {
                    let t = p.value(forKey: key) as? UITouch
                    
                    if (t != nil && t == touch)
                    {
                        p.frame = CGRect(x: loc.x - tsize / 2, y: loc.y - tsize / 2, width: CGFloat(tsize), height: CGFloat(tsize))
                    }
                }
                
                CATransaction.commit()
                break
            case .ended, .cancelled:
                for p in points {
                    let t = p.value(forKey: key) as? UITouch
                    if (t != nil && t == touch)
                    {
                        p.setValue(nil, forKey: key)
                        p.opacity = 0
                        p.removeFromSuperlayer()
                        count-=1
                    }
                }
                
                break
            default:
                break
            }
        }
    }
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    // MARK: Properties
    
    var customWindow: TouchWindow?
	var window: UIWindow?
    {
        get {
            customWindow = customWindow ?? TouchWindow(frame: UIScreen.main.bounds)
            return customWindow
        }
        set { }
    }
    
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
            defaults?.set(16, forKey: "MIDIKeycenterCC")
            defaults?.set(17, forKey: "MIDIKeyqualityCC")
            defaults?.set(true, forKey: "MIDIRecPC")
            defaults?.set(false, forKey: "MIDISendNotesMel")
            defaults?.set(false, forKey: "MIDISendNotesHarm")
        }
    }
}
