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
    
    public func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        
        var pickerLabel: UILabel?
        if (view != nil)
        {
            pickerLabel = view as? UILabel
        }
        else
        {
            pickerLabel = UILabel()
        }
        //var titleData : String = String()
        
        pickerLabel!.text = pickerData[row]
        
        pickerLabel!.backgroundColor = UIColor.clear
        pickerLabel!.textColor = UIColor.white
        
//        if (component == currInterval)
//        {
//            pickerLabel!.backgroundColor = UIColor.red
//        }
        pickerLabel!.textAlignment = .center
        
        return pickerLabel!
        
        //return pickerData[row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // This method is triggered whenever the user makes a change to the picker selection.
        // The parameter named row and component represents what was selected.
        var key: String
        for k in 0...nc-1 {
            
            if (pickerView == intervalChoosers![k]) {
                key = "interval_\(nc*component + k + keyQuality*12*nc)"
                let param = paramTree!.value(forKey: key) as? AUParameter
                param!.value = Float(row - unisonOffset)
            }
        }
    }
    
    //MARK: Properties
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var navBar: UINavigationBar!
    var pickerData: [String] = [String]()
    
    @IBOutlet weak var qualitySeg: UISegmentedControl!
    
    @IBOutlet weak var degreeStack: UIStackView!
    @IBOutlet weak var intervalStack: UIStackView!
    
    var currInterval = 0
    
    var intervalChoosers: [UIPickerView]?
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            print("set audio unit in config view controller!")
            paramTree = audioUnit!.parameterTree
            let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
            
            let keycenter = keycenterParam!.value
            
            nc = (intervalChoosers?.count)!
            
            keyQuality = Int(keycenter / 12)
            keyRoot = Int(keycenter) % 12
            qualitySeg.selectedSegmentIndex = keyQuality
        }
    }
    
    var paramTree: AUParameterTree?
    
    var keyQuality = 0
    var keyRoot = 0
    var unisonOffset = 12
    var nc = 4
    
    var timer = Timer()
    
    func auPoller(T: Float){
        // Scheduling timer to Call the timerFunction
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(timerFunction), userInfo: nil, repeats: true)
    }
    
    func timerFunction()
    {
        guard let audioUnit = audioUnit else { return }
        let note = audioUnit.getCurrentNote()
        
        if (note == -1.0)
        {
            return
        }
        
        let i = Int(round(note)) % 12
        let k = Int(audioUnit.getCurrentKeycenter()) % 12
        
        let oldInterval = currInterval
        currInterval = (i - k + 12) % 12

        let keycenterLabels = degreeStack.arrangedSubviews
        
        for l in 0...keycenterLabels.count-1
        {
            let layer = keycenterLabels[l].layer
            CATransaction.begin()
            if (l == currInterval)
            {
                CATransaction.setAnimationDuration(0.05)
                layer.borderColor = UIColor.red.cgColor
                layer.shadowColor = UIColor.red.cgColor
                layer.shadowOpacity = 1
            }
            else
            {
                layer.borderColor = UIColor.darkGray.cgColor
                layer.shadowOpacity = 0
            }
            CATransaction.commit()
        }
        
        
//        if (oldInterval != currInterval)
//        {
//            DispatchQueue.main.async {
//                for c in self.intervalChoosers!
//                {
//                    c.reloadAllComponents()
//                }
//            }
//        }
        
        return
    }
        
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        auPoller(T: 0.1)
        
        intervalChoosers = intervalStack.arrangedSubviews as? [UIPickerView]
        
        for k in 0...nc-1
        {
            self.intervalChoosers![k].delegate = self
            self.intervalChoosers![k].dataSource = self
            self.intervalChoosers![k].layer.cornerRadius = 8
            self.intervalChoosers![k].backgroundColor = UIColor.black
            //self.intervalChoosers![k].foregroundColor = UIColor.white
            
            
        }
        
        let keycenterLabels = degreeStack.arrangedSubviews
        
        for l in 0...keycenterLabels.count-1
        {
            let layer = keycenterLabels[l].layer
            keycenterLabels[l].layer.cornerRadius = 4
            keycenterLabels[l].layer.borderWidth = 4
            keycenterLabels[l].layer.borderColor = UIColor.darkGray.cgColor
            keycenterLabels[l].layer.shadowColor = UIColor.darkGray.cgColor
            keycenterLabels[l].layer.shadowRadius = 8
            keycenterLabels[l].layer.shadowOffset = CGSize(width: 0, height: 0)
            keycenterLabels[l].layer.shadowOpacity = 0
            keycenterLabels[l].layer.backgroundColor = UIColor.white.cgColor
        }

        pickerData = ["-12","-11","-10","-9","-8","-7","-6","-5","-M3","-m3","-M2","-m2",
                      "U","m2","M2","m3","M3","P4","d5","P5","m6","M6","m7","M7","P8","m9","M9","m10","M10"]
        
        doneButton.title = "Done"
    }
    
    public func refresh()
    {
        guard audioUnit != nil else { return }
        
        
        keyQuality = qualitySeg.selectedSegmentIndex
        qualitySeg!.selectedSegmentIndex = keyQuality
        
        let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
        
        keycenterParam!.value = Float(keyQuality * 12 + keyRoot)
        
        for j in 0...11
        {
            for k in 0...nc-1
            {
                let key = "interval_\(nc*j + k + keyQuality*12*nc)"
                let param = paramTree!.value(forKey: key) as? AUParameter
                intervalChoosers![k].selectRow(Int(param!.value)+unisonOffset, inComponent: j, animated: true)
            }
        }
        
    }
    
    @IBAction func done(_ sender: AnyObject?)
    {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func setQuality(_ sender: UISegmentedControl?)
    {
        refresh()
    }
}
