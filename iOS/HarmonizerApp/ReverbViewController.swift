//
//  ReverbViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 11/15/17.
//

import Foundation
import UIKit
import AudioToolbox

public class ReverbViewController: UIViewController,UITableViewDataSource, UITableViewDelegate {
    
    //@IBOutlet weak var presets: UIPickerView!
    @IBOutlet weak var paramTable: UITableView!
    @IBOutlet weak var doneButton: UIButton!
    
    @IBOutlet weak var presetTable: UITableView!
    var mixParam: AUParameter?
    var gainParam: AUParameter?
    var audioUnit: AUAudioUnit?
    
    var params = [AUParameter]()
    
    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }
    
    //MARK: UITableView
    
    public func numberOfSections(in view: UITableView) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch tableView {
        case paramTable:
            return min(params.count,2)
        case presetTable:
            return audioUnit!.factoryPresets!.count
        default:
            return 0
        }
    }
    
    public func tableView(_ tableView: UITableView,
                          titleForHeaderInSection section: Int) -> String? {
        switch tableView {
        case paramTable:
            return "Parameters"
        case presetTable:
            return "Presets"
        default:
            return "???"
        }
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch tableView {
        
        case paramTable:
            let cellIdentifier = "ReverbParameterTableCell"
            
            guard let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath) as? AUParameterTableViewCell  else {
                fatalError("The dequeued cell is not an instance of AUParameterTableViewCell.")
            }
            
            cell.nameLabel.text = params[indexPath.row].displayName
            
            cell.valueSlider.minimumValue = params[indexPath.row].minValue
            cell.valueSlider.maximumValue = params[indexPath.row].maxValue
            
            cell.valueSlider.value = params[indexPath.row].value
            cell.valueSlider.tag = indexPath.row
            
            return cell
        case presetTable:
            let cell = tableView.dequeueReusableCell(withIdentifier: "presetCell", for: indexPath)
            cell.textLabel!.text = audioUnit!.factoryPresets![indexPath.row].name
            return cell
        default:
            fatalError("Bad Table")
            
        }
        
    }
    
    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if (tableView != presetTable) { return }
        audioUnit!.currentPreset = audioUnit!.factoryPresets![indexPath.row]
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
//        self.presets.delegate = self
//        self.presets.dataSource = self
        paramTable.dataSource = self
        paramTable.tableFooterView = UIView()
        
        presetTable.dataSource = self
        presetTable.delegate = self
        presetTable.tableFooterView = UIView()
        
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
        
        //presets.selectRow(pix, inComponent: 0, animated: true)
        let ixPath = IndexPath(row: pix, section: 0)
        presetTable.selectRow(at: ixPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
        presetTable.scrollToRow(at: ixPath, at: .middle, animated: true)
    }

    //MARK: Actions
    
    @IBAction func changeValue(_ sender: UISlider) {
        params[sender.tag].value = sender.value
    }
}
