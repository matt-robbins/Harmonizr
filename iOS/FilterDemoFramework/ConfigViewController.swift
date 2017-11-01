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
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    //MARK: Properties
    
    @IBOutlet weak var scaleChooser: UIPickerView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    var pickerData: [String] = [String]()
    public override func viewDidLoad() {
        super.viewDidLoad()
        //self.scaleChooser.delegate = self
        //self.scaleChooser.dataSource = self
        pickerData = ["1", "2", "3", "4"]
        
        doneButton.title = "Done"
    }
    
    @IBAction func done(_ sender: AnyObject?)
    {
        self.dismiss(animated: true, completion: nil)
    }
}
