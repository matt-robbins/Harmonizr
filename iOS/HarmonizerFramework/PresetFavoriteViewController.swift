//
//  PresetFavoriteViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 3/23/18.
//

import UIKit

class PresetFavoriteViewController: UIViewController,UIPickerViewDelegate,UIPickerViewDataSource {
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return presetController!.presets.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String?
    {
        return presetController!.presets[row].name
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // This method is triggered whenever the user makes a change to the picker selection.
        // The parameter named row and component represents what was selected.

    }
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var presetPicker: UIPickerView!
    
    @IBOutlet weak var navBar: UINavigationBar!
    
    var presetController: PresetController?
    var favIx: Int = 0
    
    var doneFcn: (() -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        presetPicker.delegate = self
        presetPicker.dataSource = self
        
        navBar.topItem?.title = "Quick Preset \(favIx + 1)"
        
        presetController = PresetController()
        presetController!.loadPresets()
        
        presetPicker.selectRow(favIx, inComponent: 0, animated: true)
        
        // Do any additional setup after loading the view.
    }

    @IBAction func done(_ sender: Any) {
        let row = presetPicker.selectedRow(inComponent: 0)
        print(row)
        presetController?.favorites[favIx] = row
        presetController?.storePresets()
        doneFcn!()
        self.dismiss(animated: true)
    }
}
