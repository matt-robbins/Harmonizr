//
//  ConfigViewController.swift
//  iOSFilterDemoFramework
//
//  Created by Matthew E Robbins on 11/1/17.
//

import Foundation
import UIKit
import AudioToolbox

protocol PresetSaveDelegate: class {
    func configViewControllerGetPresetIx(_ controller: ConfigViewController) -> Int
    func configViewControllerGetPresets(_ controller: ConfigViewController) -> [String]
}

class KeyboardEditorView: KeyboardView {
    var xpos: CGFloat = -1.0
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        xpos = (touches.first?.location(in:self).x)!
        return
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        calculate_movement(touches,true)
        return
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        calculate_movement(touches,false)
        return
    }
}

public class ConfigViewController: UIViewController,UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate, KeyboardViewDelegate, VoicesViewDelegate {
    func voicesView(_ view: HarmonizerVoicesView, didChangeInversion inversion: Float) {
        let param = paramTree!.value(forKey: "inversion") as? AUParameter
        param!.value = inversion
        drawKeys()
    }
    
    func voicesView(_ view: HarmonizerVoicesView, didChangeNvoices voices: Float) {
        let param = paramTree!.value(forKey: "nvoices") as? AUParameter
        param!.value = voices
    }
    
    
    func keyboardView(_ view: KeyboardView, noteOn note: Int) {
        return
    }
    
    func keyboardView(_ view: KeyboardView, noteOff note: Int) {
        return
    }
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return nc
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
        
        pickerLabel!.text = pickerData[row]
        
        pickerLabel!.backgroundColor = UIColor.clear
        pickerLabel!.textColor = UIColor.white
        
        pickerLabel!.textAlignment = .center
        
        return pickerLabel!        
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        // This method is triggered whenever the user makes a change to the picker selection.
        // The parameter named row and component represents what was selected.
        var key: String
        
        key = "interval_\(nc*scaleDegree + component + keyQuality*12*nc)"
        let param = paramTree!.value(forKey: key) as? AUParameter
        param!.value = Float(row - unisonOffset)
        
        print("changed!")
        presetNeedsSave = true
        syncPresetButtons()
        drawKeys()
    }
    
    //MARK: Properties
    
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var navBar: UINavigationBar!
    var pickerData: [String] = [String]()
    
    @IBOutlet weak var qualitySeg: UISegmentedControl!
    
    @IBOutlet weak var degreeStack: UIStackView!
    @IBOutlet weak var rootStack: UIStackView!
    
    @IBOutlet weak var intervalPicker: UIPickerView!
    
    @IBOutlet weak var presetName: UITextField!
    @IBOutlet weak var presetPrevButton: HarmButton!
    @IBOutlet weak var presetNextButton: HarmButton!
    @IBOutlet weak var presetAddButton: UIButton!
    
    @IBOutlet weak var liveSwitch: UISwitch!
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var revertButton: HarmButton!
    
    @IBOutlet weak var voicesView: HarmonizerVoicesView!
    @IBOutlet weak var keyboardView: KeyboardEditorView!
    var preset: Preset?
    
    var doneFcn: (() -> Void)?
    
    var presetIx: Int = 0
    var presetController: PresetController? {
        didSet {
            presetName!.text = presetController!.currentPreset().name
            presetName!.isEnabled = !presetController!.currentPreset().isFactory
            
            presetIx = presetController!.presetIx
        }
    }
    
    var currInterval = 0
    
    public var audioUnit: AUv3Harmonizer? {
        didSet {
            print("set audio unit in config view controller!")
            paramTree = audioUnit!.parameterTree
            let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
            let inversionParam = paramTree!.value(forKey: "inversion") as? AUParameter
            let nvoicesParam = paramTree!.value(forKey: "nvoices") as? AUParameter
            
            voicesView.setSelectedVoices(Int(nvoicesParam!.value), inversion: Int(inversionParam!.value))
            let keycenter = keycenterParam!.value
            
            keyQuality = Int(keycenter / 12)
            keyRoot = Int(keycenter) % 12
            qualitySeg.selectedSegmentIndex = keyQuality
            
            let buttons = rootStack.arrangedSubviews as! [HarmButton]
            for c in 0...buttons.count - 1
            {
                buttons[c].isSelected = (c == keyRoot)
            }
            
            setRoot(nil)
        }
    }
    
    var presetNeedsSave: Bool = false {
        didSet {
            
        }
    }
    
    var paramTree: AUParameterTree?
    
    var keyQuality = 0
    var keyRoot = 0
    var scaleDegree = 0
    var unisonOffset = 12
    var nc = 4
    
    var timer = Timer()
    
    func auPoller(T: Float){
        // Scheduling timer to Call the timerFunction
        timer = Timer.scheduledTimer(timeInterval: TimeInterval(T), target: self, selector: #selector(timerFunction), userInfo: nil, repeats: true)
    }
    
    @objc func timerFunction()
    {
        guard let audioUnit = audioUnit else { return }
        let note = audioUnit.getCurrentNote()
        
        if (note == -1.0)
        {
            currInterval = -1
        }
        else
        {
            let i = Int(round(note)) % 12
            let k = Int(audioUnit.getCurrentKeycenter()) % 12
            
            currInterval = (i - k + 12) % 12
        }

        let buttons = degreeStack.arrangedSubviews as! [HarmButton]
        
        for d in 0...buttons.count-1
        {
            let b = buttons[d]
            CATransaction.begin()
            
            if (d == currInterval)
            {
                if (liveSwitch.isOn && !b.isBeingPlayed)
                {
                    setDegree(b)
                }
                
                b.isBeingPlayed = true
            }
            else
            {
                b.isBeingPlayed = false
            }
            
            CATransaction.commit()
        }
        
        if (currInterval == scaleDegree)
        {
            intervalPicker!.layer.shadowOpacity = 1.0
            intervalPicker!.layer.borderColor = UIColor.cyan.cgColor
        }
        else
        {
            intervalPicker!.layer.shadowOpacity = 0.0
            intervalPicker!.layer.borderColor = UIColor.darkGray.cgColor
        }
        
        return
    }
        
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        keyboardView.delegate = self
        voicesView.delegate = self
        
        intervalPicker!.delegate = self
        intervalPicker!.dataSource = self
        intervalPicker!.layer.cornerRadius = 8
        intervalPicker!.backgroundColor = UIColor.black
        intervalPicker!.layer.borderWidth = 2
        intervalPicker!.layer.borderColor = UIColor.darkGray.cgColor
        intervalPicker!.layer.shadowColor = UIColor.cyan.cgColor
        intervalPicker!.layer.shadowRadius = 8
        intervalPicker!.layer.shadowOffset = CGSize(width: 0, height: 0)
        intervalPicker!.layer.shadowOpacity = 0
        
        let d = degreeStack.arrangedSubviews[0] as! HarmButton
        d.isSelected = true

        pickerData = ["-12","-11","-10","-9","-8","-7","-6","-5","-M3","-m3","-M2","-m2","U","m2","M2","m3","M3","P4","d5","P5","m6","M6","m7","M7","P8","m9","M9","m10","M10"]
        
        pickerData = ["-12","-11","-10","-9","-8","-7","-6","-5","-4","-3","-2","-1","0",
                      "1","2","3","4","5","6","7","8","9","10","11","12","13","14","15","16"]
        
        presetName.delegate = self
        saveButton.isEnabled = false
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name:NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name:NSNotification.Name.UIKeyboardWillHide, object: nil)
    }
    
    @objc func keyboardWillShow(notification: NSNotification)
    {
        var info = notification.userInfo!
        let keyboardSize = (info[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue.size
        
        let frame = presetName.convert(presetName.frame, from:self.view)
        print(self.view.frame.height)
        print(frame.minY)
        print(keyboardSize!.height)
        let scrollHeight = (self.view.frame.height + frame.minY - frame.height - keyboardSize!.height)
        
        if (scrollHeight < 0)
        {
            self.view.window?.frame.origin.y = scrollHeight
        }
        
    }
    @objc func keyboardWillHide(notification: NSNotification)
    {
        self.view.window?.frame.origin.y = 0
    }
    
    public override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)
        syncPresetButtons()
        preset = Preset(name: "current",data: presetController!.getPreset(), isFactory: false)
        auPoller(T: 0.1)
    }
    
    public override func viewWillDisappear(_ animated: Bool)
    {
        super.viewWillDisappear(animated)
        timer.invalidate()
    }
    
    public func drawKeys()
    {
        for k in keyboardView.keys
        {
            k.isSelected = false
            if (k.midinote) == 60 + (keyRoot + scaleDegree) % 12
            {
                k.isSelected = true
                keyboardView.keyOffset = Int(k.midinote * 7/12) - 3
            }
        }
        
        for k in 0...nc-1
        {
            let key = "interval_\(nc*scaleDegree + k + keyQuality*12*nc)"
            var param = paramTree!.value(forKey: key) as? AUParameter
            var offset = Int(param!.value)
            
            param = paramTree!.value(forKey: "inversion") as? AUParameter
            let inversion = Int(param!.value)
            print(inversion)
            if (k > inversion)
            {
                offset -= 12
            }
            
            for k in keyboardView.keys
            {
                if (k.midinote) == 60 + offset + (keyRoot + scaleDegree) % 12
                {
                    k.isHarm = true
                }
            }
        }
    }
    
    public func refresh()
    {
        guard audioUnit != nil else { return }
        
        keyQuality = qualitySeg.selectedSegmentIndex
        qualitySeg!.selectedSegmentIndex = keyQuality
        
        let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
        
        keycenterParam!.value = Float(keyQuality * 12 + keyRoot)
        
        for k in keyboardView.keys
        {
            k.isSelected = false
            if (k.midinote) == 60 + (keyRoot + scaleDegree) % 12
            {
                k.isSelected = true
                keyboardView.keyOffset = Int(k.midinote * 7/12) - 3
            }
        }
        
        for k in 0...nc-1
        {
            let key = "interval_\(nc*scaleDegree + k + keyQuality*12*nc)"
            let param = paramTree!.value(forKey: key) as? AUParameter
            let offset = Int(param!.value)
            
            for k in keyboardView.keys
            {
                if (k.midinote) == 60 + offset + (keyRoot + scaleDegree) % 12
                {
                    k.isHarm = true
                }
            }
            
            intervalPicker!.selectRow(offset+unisonOffset, inComponent: k, animated: true)
        }
        
        
        
    }
    
    //MARK: Actions
    @IBAction func done(_ sender: AnyObject?)
    {
        if (presetNeedsSave)
        {
            savePreset(saveButton)
        }
        
        if (doneFcn != nil)
        {
            doneFcn!()
        }
        
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func setQuality(_ sender: UISegmentedControl?)
    {
        refresh()
    }
    
    @IBAction func setRoot(_ sender: HarmButton?)
    {
        let colors = [0,1,0,1,0,0,1,0,1,0,1,0]
        //let keycenterParam = paramTree!.value(forKey: "keycenter") as? AUParameter
        
        var r = 0
        for b in rootStack.arrangedSubviews as! [HarmButton]
        {
            if (b == sender)
            {
                keyRoot = r
                b.isSelected = true
            }
            else
            {
                b.isSelected = false
            }
            r = r + 1
        }
        
        var ix = 0
        for b in degreeStack.arrangedSubviews as! [HarmButton]
        {
            b.backgroundColor = colors[(ix + keyRoot) % 12] == 1 ? UIColor.black : UIColor.white
            b.configure()
            ix += 1
            
        }
        refresh()
        drawKeys()

    }
    
    @IBAction func setDegree(_ sender: HarmButton?)
    {
        var degree = 0
        for b in degreeStack.arrangedSubviews as! [HarmButton]
        {
            if (b == sender)
            {
                scaleDegree = degree
                b.isSelected = true
            }
            else
            {
                b.isSelected = false
            }
            degree = degree + 1
        }
        
        refresh()
        drawKeys()
    }
    @IBAction func presetNext(_ sender: Any) {
        if (presetIx < presetController!.presets.count - 1)
        {
            presetIx = presetIx + 1
            presetNeedsSave = true
            syncPresetButtons()
        }
    }
    
    @IBAction func presetPrev(_ sender: Any) {
        if (presetIx > 0)
        {
            presetIx = presetIx - 1
            presetNeedsSave = true
            syncPresetButtons()
        }
    }
    
    @IBAction func changePresetName(_ sender: UITextField) {
        presetNeedsSave = true
        presetController!.presets[presetIx].name = sender.text
        syncPresetButtons()
    }
    
    @IBAction func savePreset(_ sender: Any) {
        presetController?.writePreset(name: presetName.text!, ix: presetIx)
        presetNeedsSave = false
        syncPresetButtons()
    }
    
    @IBAction func revertPreset(_ sender: HarmButton) {
        presetNeedsSave = false
        presetController!.restoreState()
        presetIx = presetController!.presetIx
        syncPresetButtons()
    }
    
    @IBAction func addPreset(_ sender: Any) {
        presetController!.appendPreset()
        presetNeedsSave = true
        presetIx = presetController!.presets.count - 1
        syncPresetButtons()
        presetName!.becomeFirstResponder()
    }
    
    
    func syncPresetButtons()
    {
        let nameText = presetController!.presets[presetIx].name! + (presetController!.presets[presetIx].isFactory ? " (factory)" : "")
        presetName!.text = nameText
        presetName!.isEnabled = !presetController!.presets[presetIx].isFactory
        
        presetName!.textColor = presetName.isEnabled ? UIColor.white : UIColor.lightGray

        presetPrevButton.isEnabled = (presetIx > 0)
        presetNextButton.isEnabled = (presetIx < presetController!.presets.count - 1)
        
        saveButton.isEnabled = presetNeedsSave && presetName!.isEnabled
        revertButton.isEnabled = saveButton.isEnabled
        doneButton.title = saveButton.isEnabled ? "Save" : "Done"
    }
    
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        self.presetName.resignFirstResponder()
        return true
    }
    
}
