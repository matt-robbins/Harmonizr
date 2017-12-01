//
//  ConfigViewController.swift
//  iOSFilterDemoFramework
//
//  Created by Matthew E Robbins on 11/1/17.
//

import Foundation
import UIKit

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
        if (pickerView == interval1Chooser) {
            key = "interval_\(2*component + keyOffset)"
        }
        else {
            key = "interval_\(2*component + 1 + keyOffset)"
        }
        
        let param = paramTree!.value(forKey: key) as? AUParameter
        param!.value = Float(row)
        
    }
    
    //MARK: Properties
    
    @IBOutlet weak var interval1Chooser: UIPickerView!
    @IBOutlet weak var interval2Chooser: UIPickerView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    @IBOutlet weak var navBar: UINavigationBar!
    var pickerData: [String] = [String]()
    
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            print("set audio unit in config view controller!")
        }
    }
    
    var paramTree: AUParameterTree?
    
    var keyOffset = 0
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        self.interval1Chooser.delegate = self
        self.interval1Chooser.dataSource = self
        self.interval2Chooser.delegate = self
        self.interval2Chooser.dataSource = self
        pickerData = ["U","m2","M2","m3","M3","P4","d5","P5","m6","M6","m7","M7","P8"]
        
        
        doneButton.title = "Done"
        
        refresh()
    }
    
    public func refresh()
    {
        guard audioUnit != nil else { return }
        
        paramTree = audioUnit!.parameterTree
        let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
        
        let keycenter = keycenterParam!.value
        print(keycenter)
        keyOffset = Int(keycenter / 12) * 24
        
        var keytype: String = "Major"
        
        if (keyOffset == 24)
        {
            keytype = "Minor"
        }
        
        if (keyOffset == 48)
        {
            keytype = "Dominant"
        }
        
        navBar.topItem?.title = "Configure (\(keytype))"
        
        for j in 0...11
        {
            var key = "interval_\(2*j + keyOffset)"
            var param = paramTree!.value(forKey: key) as? AUParameter
            interval1Chooser.selectRow(Int(param!.value), inComponent: j, animated: false)
            key = "interval_\(2*j + 1 + keyOffset)"
            param = paramTree!.value(forKey: key) as? AUParameter
            interval2Chooser.selectRow(Int(param!.value), inComponent: j, animated: false)
        }
        
    }
    
    @IBAction func done(_ sender: AnyObject?)
    {
        self.dismiss(animated: true, completion: nil)
    }
}
