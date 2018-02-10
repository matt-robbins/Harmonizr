//
//  ConfigViewController.swift
//  iOSFilterDemoFramework
//
//  Created by Matthew E Robbins on 11/1/17.
//

import Foundation
import UIKit
import AudioToolbox

public class ConfigViewController: UIViewController,UIPickerViewDelegate, UIPickerViewDataSource {
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 12
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // This method is triggered whenever the user makes a change to the picker selection.
        // The parameter named row and component represents what was selected.
        var key: String
        for k in 0...nc-1 {
            
            if (pickerView == intervalChoosers[k]) {
                key = "interval_\(nc*component + k + keyQuality*12*nc)"
                let param = paramTree!.value(forKey: key) as? AUParameter
                param!.value = Float(row - unisonOffset)
                
            }
        }
    }
    
    //MARK: Properties
    
    @IBOutlet weak var interval1Chooser: UIPickerView!
    @IBOutlet weak var interval2Chooser: UIPickerView!
    @IBOutlet weak var interval3Chooser: UIPickerView!
    @IBOutlet weak var interval4Chooser: UIPickerView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var navBar: UINavigationBar!
    var pickerData: [String] = [String]()
    
    @IBOutlet var intervalChoosers: [UIPickerView]!
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            print("set audio unit in config view controller!")
        }
    }
    
    var paramTree: AUParameterTree?
    
    var keyQuality = 0
    var unisonOffset = 12
    var nc = 4
        
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        for k in 0...nc-1
        {
            self.intervalChoosers[k].delegate = self
            self.intervalChoosers[k].dataSource = self
        }

        pickerData = ["-12","-11","-10","-9","-8","-7","-6","-5","-4","-3","-2","-1",
                      "U","m2","M2","m3","M3","P4","d5","P5","m6","M6","m7","M7","P8","m9","M9","m10","M10"]
        
        doneButton.title = "Done"
        
        refresh()
    }
    
    public func refresh()
    {
        guard audioUnit != nil else { return }
        
        paramTree = audioUnit!.parameterTree
        let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
        
        let keycenter = keycenterParam!.value
        
        nc = intervalChoosers.count
        
        keyQuality = Int(keycenter / 12)
        
        var keytype: String = "Major"
        
        if (keyQuality == 1)
        {
            keytype = "Minor"
        }
        
        if (keyQuality == 2)
        {
            keytype = "Dominant"
        }
        
        navBar.topItem?.title = "Configure (\(keytype))"
        
        for j in 0...11
        {
            for k in 0...nc-1
            {
                let key = "interval_\(nc*j + k + keyQuality*12*nc)"
                let param = paramTree!.value(forKey: key) as? AUParameter
                intervalChoosers[k].selectRow(Int(param!.value)+unisonOffset, inComponent: j, animated: true)
            }
        }
        
    }
    
    @IBAction func done(_ sender: AnyObject?)
    {
        self.dismiss(animated: true, completion: nil)
    }
}
