//
//  ReverbViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 11/15/17.
//

import Foundation
import UIKit
import AudioToolbox

public class ReverbViewController: UIViewController,UIPickerViewDelegate,UIPickerViewDataSource,UITableViewDataSource {
    
    @IBOutlet weak var presets: UIPickerView!
    @IBOutlet weak var paramTable: UITableView!
    @IBOutlet weak var doneButton: UIButton!
    
    var mixParam: AUParameter?
    var gainParam: AUParameter?
    var audioUnit: AUAudioUnit?
    
    var params = [AUParameter]()
    
    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }
    
    //MARK: uiPickerView
    
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
        for p in params {
            print(p.value)
        }
        self.paramTable.reloadData()
        
    }
    
    public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        
        return NSAttributedString(string: audioUnit!.factoryPresets![row].name, attributes: [NSAttributedStringKey.foregroundColor:UIColor.white])
    }
    
    //MARK: UITableView
    
    public func numberOfSections(in view: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return min(params.count,2)
    }
    
    public func tableView(_ tableView: UITableView,
                          titleForHeaderInSection section: Int) -> String? {
        return "Parameters"
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cellIdentifier = "ReverbParameterTableCell"
        
        guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? AUParameterTableViewCell  else {
            fatalError("The dequeued cell is not an instance of AUParameterTableViewCell.")
        }
        
        print("Setting table stuff!")
        
        cell.nameLabel.text = params[indexPath.row].displayName
        
        cell.valueSlider.minimumValue = params[indexPath.row].minValue
        cell.valueSlider.maximumValue = params[indexPath.row].maxValue
        
        cell.valueSlider.value = params[indexPath.row].value
        cell.valueSlider.tag = indexPath.row
        
        return cell
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        self.presets.delegate = self
        self.presets.dataSource = self
        paramTable.dataSource = self
        
        paramTable.tableFooterView = UIView()
        
        //self.view.backgroundColor = UIColor.darkGray
        
        params = audioUnit!.parameterTree!.allParameters
                
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

    //MARK: Actions
    
    @IBAction func changeValue(_ sender: UISlider) {
        params[sender.tag].value = sender.value
    }
}
