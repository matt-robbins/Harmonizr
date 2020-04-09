//
//  HarmonizrMainViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 7/19/18.
//

import UIKit
import CoreAudioKit
import os
import Foundation
import AVFoundation

public var globalAudioUnit: AUv3Harmonizer?

public protocol InterfaceDelegate {
    func didToggleRecording(_ onOff:Bool) -> Bool
    func getReverbUnit() -> AUAudioUnit?
    func getInputViewController() -> UIViewController?
    func showNavBar(_ show:Bool)
}

public class HarmonizrMainViewController: AUViewController, UINavigationControllerDelegate {

    @IBOutlet var containerView: UIView!
    
    var navController: UINavigationController?
    var harmViewController: HarmonizerViewController?
    
    var midiClient: MIDIClientRef = MIDIClientRef()
    var midiOutput: MIDIPortRef = MIDIPortRef()
    public var interfaceDelegate: InterfaceDelegate?
    {
        didSet {
            harmViewController!.interfaceDelegate = interfaceDelegate
        }
    }
    
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            globalAudioUnit = audioUnit
            
            if (harmViewController != nil)
            {
                harmViewController?.audioUnit = globalAudioUnit
            }
        }
    }
    
    var keys = ["z","x","c","v","a","s","d","f","q","w","e","r"]
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        UITableViewCell.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().backgroundColor = UIColor.clear
        UITableView.appearance().separatorColor = UIColor.lightGray
        UITableViewHeaderFooterView.appearance().tintColor = UIColor.darkGray
        UILabel.appearance(whenContainedInInstancesOf: [UITableView.self]).textColor = UIColor.white
        UILabel.appearance(whenContainedInInstancesOf: [UITableView.self]).highlightedTextColor = UIColor.lightGray
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).textColor = UIColor.white
        UILabel.appearance(whenContainedInInstancesOf: [UITableViewCell.self]).highlightedTextColor = UIColor.lightGray
        BaseView.appearance().backgroundColor = UIColor.clear
        UIPickerView.appearance().backgroundColor = UIColor.clear
        UINavigationBar.appearance().barStyle = .black
        UINavigationBar.appearance().backgroundColor = UIColor.darkGray
        
        MIDIClientCreate("HarmonizrOutput" as CFString, nil, nil, &midiClient);
        MIDIOutputPortCreate(midiClient, "Harmonizr_Output" as CFString, &midiOutput);
    }

    override public func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: UINavigationControllerDelegate
    
    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool)
    {
        navController!.setNavigationBarHidden(viewController == navController!.viewControllers.first, animated: animated)
        
        if (viewController == navController!.viewControllers.first)
        {
            let vc = viewController as? HarmonizerViewController
            vc!.presetController!.loadPresets()
            vc!.syncView()
        }
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        containerView.frame = (view.superview?.bounds)!
    }
    
    public func getVideoView() -> UIView?
    {
        return harmViewController?.getVideoView()
    }
    
    //MARK: - Keyboard Input
    
    override public var keyCommands: [UIKeyCommand]? {
        
        var cmds = [UIKeyCommand]()
                
        let kcenters = ["C","C#/Db","D","D#/Eb","E","F","F#/Gb","G","G#/Ab","A","A#/Bb","B"]
        
        for k in 0...keys.count-1 {
            cmds.append(UIKeyCommand(input: keys[k], modifierFlags: [], action: #selector(keyboardInput), discoverabilityTitle: "\(kcenters[k]) Major"))
            cmds.append(UIKeyCommand(input: keys[k], modifierFlags: [.control], action: #selector(keyboardInput), discoverabilityTitle: "\(kcenters[k]) Minor"))
            cmds.append(UIKeyCommand(input: keys[k], modifierFlags: [.shift], action: #selector(keyboardInput), discoverabilityTitle: "\(kcenters[k]) Dominant"))
        }
        
        cmds.append(UIKeyCommand(input: UIKeyInputLeftArrow, modifierFlags: [], action: #selector(keyboardInput), discoverabilityTitle: "Decrease Number of Voices"))
        
        cmds.append(UIKeyCommand(input: UIKeyInputRightArrow, modifierFlags: [], action: #selector(keyboardInput), discoverabilityTitle: "Increase Number of Voices"))
        
        cmds.append(UIKeyCommand(input: UIKeyInputUpArrow, modifierFlags: [], action: #selector(keyboardInput), discoverabilityTitle: "Raise Inversion"))
        
        cmds.append(UIKeyCommand(input: UIKeyInputDownArrow, modifierFlags: [], action: #selector(keyboardInput), discoverabilityTitle: "Lower Inversion"))
        
        return cmds
    }
    
    @objc func keyboardInput(sender: UIKeyCommand)
    {
        //print(sender.input ?? "?", sender.modifierFlags)
        //audioUnit?.parameterTree.parameter(withAddress: "keycenter").set
        
        let kP = audioUnit?.parameterTree?.value(forKey: "keycenter") as? AUParameter
        let sP = audioUnit?.parameterTree?.value(forKey: "nvoices") as? AUParameter
        let iP = audioUnit?.parameterTree?.value(forKey: "inversion") as? AUParameter
        switch (sender.input)
        {
        case UIKeyInputLeftArrow:
            sP?.value = (sP?.value ?? 1.0) - 1.0
        case UIKeyInputRightArrow:
            sP?.value = (sP?.value ?? 1.0) + 1.0
        case UIKeyInputUpArrow:
            iP?.value = (iP?.value ?? 1.0) + 1.0
        case UIKeyInputDownArrow:
            iP?.value = (iP?.value ?? 1.0) - 1.0
        default:
            let kc = keys.index(of: sender.input ?? "z") ?? 0
            var kq = 0
            if (sender.modifierFlags.contains(.control))
            {
                kq = 1
            }
            if (sender.modifierFlags.contains(.shift))
            {
                kq = 2
            }
            sP?.value = 4
            kP?.value = Float(kc + 12 * kq)
        }
        
        harmViewController?.syncView()
    }
    
    //MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override public func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showMainView" {
            if let destinationVC = segue.destination as? UINavigationController {
                navController = destinationVC
                navController!.delegate = self
                harmViewController = navController!.viewControllers.first as? HarmonizerViewController
                harmViewController?.audioUnit = globalAudioUnit
            }
        }
    }
}
