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
    
    
    @IBAction func changePreset(_ sender: UIButton)
    {
        print(vc!.presetIx)
        if (sender == nextButton && sender.isEnabled)
        {
            vc!.presetIx += 1
        }
        if (sender == prevButton && sender.isEnabled)
        {
            vc!.presetIx -= 1
        }
        
        presetName.text = vc!.presets[vc!.presetIx].name
        
        enableButtons()
    }
    @IBAction func save(_ sender: UIButton) {
        if (sender == saveButton)
        {
            print(presetName.text ?? "(Nil)")
            vc!.presets[vc!.presetIx].name = presetName.text
            vc!.presets[vc!.presetIx].data = presetData!
            vc!.presetModified = false
            vc!.harmonizerView.preset = vc!.presets[vc!.presetIx].name
            vc!.storePresets()
        }
        self.dismiss(animated: true, completion: nil)
    }
    
    func enableButtons()
    {
        prevButton.isEnabled = vc!.presetIx != 0
        nextButton.isEnabled = vc!.presetIx < vc!.presets.count - 1
        saveButton.isEnabled = !vc!.presets[vc!.presetIx].isFactory
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        presetName.delegate = self
        presetName.text = vc!.presets[vc!.presetIx].name
        enableButtons()
        //saveButton.isEnabled = false
        //setPreset(vc!.presetIx)
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.presetName.resignFirstResponder()
        return true
    }
}
