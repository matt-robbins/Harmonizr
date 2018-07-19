//
//  PresetSaveViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 7/17/18.
//

import UIKit

class PresetSaveViewController: UIViewController, UITextFieldDelegate {

    
    @IBOutlet weak var presetName: UITextField!
    @IBOutlet weak var saveButton: HarmButton!
    @IBOutlet weak var revertButton: HarmButton!
    
    @IBOutlet weak var presetPrevButton: HarmButton!
    @IBOutlet weak var presetNextButton: HarmButton!
    @IBOutlet weak var presetAddButton: UIButton!
    
    
    var presetNeedsSave: Bool = false
    var presetIx: Int = 0
    
    var presetController: PresetController? {
        didSet {
            if (presetName != nil)
            {
            presetName!.text = presetController!.currentPreset().name
            presetName!.isEnabled = !presetController!.currentPreset().isFactory
            
            presetIx = presetController!.presetIx
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        
        presetName.delegate = self
        saveButton.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name:NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name:NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    func syncPresetButtons()
    {
        if (presetController == nil)
        {
            return
        }
        let nameText = presetController!.presets[presetIx].name! + (presetController!.presets[presetIx].isFactory ? " (factory)" : "")
        presetName!.text = nameText
        presetName!.isEnabled = !presetController!.presets[presetIx].isFactory
        
        presetName!.textColor = presetName.isEnabled ? UIColor.white : UIColor.lightGray
        
        presetPrevButton.isEnabled = (presetIx > 0)
        presetNextButton.isEnabled = (presetIx < presetController!.presets.count - 1)
        
        saveButton.isEnabled = presetNeedsSave && presetName!.isEnabled
        revertButton.isEnabled = saveButton.isEnabled
        //doneButton.title = saveButton.isEnabled ? "Save" : "Done"
    }

    @objc func keyboardWillShow(notification: NSNotification)
    {
        var info = notification.userInfo!
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size
        
        let frame = presetName.convert(presetName.frame, from:self.view)
        let wframe = presetName.convert(presetName.frame, to: nil)
        
        if ((self.view.window?.frame.height)! - wframe.maxY < keyboardSize!.height)
        {
            self.view.window?.frame.origin.y = ((self.view.window?.frame.height)! - wframe.maxY) - keyboardSize!.height - 5
        }
        //
        //        print(self.view.frame.height)
        //        print(frame.minY)
        //        print(keyboardSize!.height)
        //        let scrollHeight = (self.view.frame.height + frame.minY - frame.height - keyboardSize!.height)
        //
        //        if (scrollHeight < 0)
        //        {
        //            self.view.window?.frame.origin.y = scrollHeight
        //        }
        
    }
    @objc func keyboardWillHide(notification: NSNotification)
    {
        self.view.window?.frame.origin.y = 0
    }
}
