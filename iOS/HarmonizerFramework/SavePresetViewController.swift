//
//  SavePresetViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 1/8/18.
//

import Foundation
import UIKit

public class SavePresetViewController: UIViewController, UITextFieldDelegate
{
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var presetName: UITextField!
    @IBOutlet weak var prevButton: UIButton!
    @IBOutlet weak var nextButton: UIButton!
    @IBOutlet weak var number: UILabel!
    public var presetData: [String: Any]!
    public var vc: HarmonizerViewController?
    
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        presetName.layer.borderColor = UIColor.darkGray.cgColor
        presetName.layer.borderWidth = 2
        presetName.layer.cornerRadius = 4
        
        prevButton.setTitleColor(.black, for: UIControlState())
        nextButton.setTitleColor(.black, for: UIControlState())
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.presetName.resignFirstResponder()
        return true
    }
}
