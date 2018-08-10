//
//  HarmonizrMainViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 7/19/18.
//

import UIKit
import CoreAudioKit
import os

public var globalAudioUnit: AUv3Harmonizer?

public class HarmonizrMainViewController: AUViewController, UINavigationControllerDelegate {

    @IBOutlet var containerView: UIView!
    
    var navController: UINavigationController?
    var harmViewController: HarmonizerViewController?
    
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            globalAudioUnit = audioUnit
            
            if (harmViewController != nil)
            {
                harmViewController?.audioUnit = globalAudioUnit
            }
        }
    }
    
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
        view.frame = (view.superview?.bounds)!
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
