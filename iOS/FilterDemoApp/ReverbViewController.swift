//
//  ReverbViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 11/15/17.
//

import Foundation
import UIKit
import AudioToolbox

public class ReverbViewController: UIViewController,UIPickerViewDelegate,UIPickerViewDataSource {
    @IBOutlet weak var presets: UIPickerView!
    @IBOutlet weak var gain: UISlider!
    @IBOutlet weak var mix: UISlider!
    @IBOutlet weak var doneButton: UIButton!
    
    var mixParam: AUParameter?
    var gainParam: AUParameter?
    var audioUnit: AUAudioUnit?
    
    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return audioUnit!.factoryPresets!.count
    }

    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return audioUnit!.factoryPresets![row].name
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        audioUnit!.currentPreset = audioUnit!.factoryPresets![row]
    }
    
    public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        
        return NSAttributedString(string: audioUnit!.factoryPresets![row].name, attributes: [NSForegroundColorAttributeName:UIColor.white])
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        self.presets.delegate = self
        self.presets.dataSource = self
        
        //self.view.backgroundColor = UIColor.darkGray
        
        mixParam = audioUnit!.parameterTree!.parameter(withAddress: AUParameterAddress(kReverb2Param_DryWetMix))
        mix.maximumValue = (mixParam?.maxValue)!
        mix.minimumValue = (mixParam?.minValue)!
        mix.value = mixParam!.value
        
        gainParam = audioUnit!.parameterTree!.parameter(withAddress: AUParameterAddress(kReverb2Param_Gain))
        gain.maximumValue = (gainParam?.maxValue)!
        gain.minimumValue = (gainParam?.minValue)!
        gain.value = gainParam!.value
        
        var pix = 0
        
        //let factory = audioUnit!.factoryPresets
        print (audioUnit!.currentPreset!.name)
        for j in 0...audioUnit!.factoryPresets!.count - 1 {
            if audioUnit!.currentPreset!.name == audioUnit!.factoryPresets![j].name {
                pix = j
            }
        }
        
        presets.selectRow(pix, inComponent: 0, animated: true)
    }
    @IBAction func changeGain(_ sender: Any) {
        gainParam!.value = gain.value
    }
    
    @IBAction func changeMix(_ sender: Any) {
        mixParam!.value = mix.value
    }
}
