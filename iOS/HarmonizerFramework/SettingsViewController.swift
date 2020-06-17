//
//  ConfigDetailViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 6/20/18.
//

import UIKit
import SafariServices
import CoreAudioKit

class SettingsViewController: UITableViewController {
    
    var keycenterParameter: AUParameter?
    var inversionParameter: AUParameter?
    var nvoicesParameter: AUParameter?
    var autoParameter: AUParameter?
    var autoStrengthParameter: AUParameter?
    var midiParameter: AUParameter?
    var midiLinkParameter: AUParameter?
    var midiLegatoParameter: AUParameter?
    var triadParameter: AUParameter?
    var bypassParameter: AUParameter?
    var speedParameter: AUParameter?
    var hgainParameter: AUParameter?
    var vgainParameter: AUParameter?
    var dryMixParameter: AUParameter?
    var synthParameter: AUParameter?
    var tuningParameter: AUParameter?
    var threshParameter: AUParameter?
    var stereoParameter: AUParameter?
    
    @IBOutlet weak var speedSlider: UISlider!
    
    @IBOutlet weak var drySwitch: UISwitch!
    @IBOutlet weak var synthSwitch: UISwitch!
    
    @IBOutlet weak var stereoModeLabel: UILabel!
    
    @IBOutlet weak var threshStepper: UIStepper!
    
    @IBOutlet weak var threshLabel: UILabel!
    
    @IBOutlet weak var levelStepper: UIStepper!
    @IBOutlet weak var levelLabel: UILabel!
    
    @IBOutlet weak var corrSwitch: UISwitch!
    @IBOutlet weak var corrStepper: UIStepper!
    @IBOutlet weak var corrLabel: UILabel!
    
    @IBOutlet weak var tuningLabel: UILabel!
    @IBOutlet weak var tuningStepper: UIStepper!
    
    @IBOutlet weak var showKeyboardSwitch: UISwitch!
    @IBOutlet weak var aboutLink: UITableViewCell!
    
    @IBOutlet weak var showTouchSwitch: UISwitch!
    var defaults: UserDefaults?
    
    var reverbAudioUnit: AUAudioUnit?
    var interfaceDelegate: InterfaceDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let paramTree = globalAudioUnit?.parameterTree else { return }
        
        keycenterParameter = paramTree.value(forKey: "keycenter") as? AUParameter
        inversionParameter = paramTree.value(forKey: "inversion") as? AUParameter
        nvoicesParameter = paramTree.value(forKey: "nvoices") as? AUParameter
        autoParameter = paramTree.value(forKey: "auto") as? AUParameter
        autoStrengthParameter = paramTree.value(forKey: "auto_strength") as? AUParameter
        midiParameter = paramTree.value(forKey: "midi") as? AUParameter
        midiLinkParameter = paramTree.value(forKey: "midi_link") as? AUParameter
        midiLegatoParameter = paramTree.value(forKey: "midi_legato") as? AUParameter
        triadParameter = paramTree.value(forKey: "triad") as? AUParameter
        bypassParameter = paramTree.value(forKey: "bypass") as? AUParameter
        speedParameter = paramTree.value(forKey: "speed") as? AUParameter
        hgainParameter = paramTree.value(forKey: "h_gain") as? AUParameter
        vgainParameter = paramTree.value(forKey: "v_gain") as? AUParameter
        dryMixParameter = paramTree.value(forKey: "dry_mix") as? AUParameter
        synthParameter = paramTree.value(forKey: "synth_enable") as? AUParameter
        
        tuningParameter = paramTree.value(forKey: "tuning") as? AUParameter
        threshParameter = paramTree.value(forKey: "threshold") as? AUParameter
        stereoParameter = paramTree.value(forKey: "stereo_mode") as? AUParameter
        
        threshLabel.text = "\(threshParameter!.value)"
        
        tuningLabel.text = "\(tuningParameter!.value) Hz"
        tuningStepper.value = Double(tuningParameter!.value)
        
        corrSwitch.isOn = autoParameter!.value > 0.5
        corrStepper.value = Double(autoStrengthParameter!.value * 100)
        corrLabel.text = "\(Int(corrStepper.value)) %"
        
        levelStepper.value = Double(hgainParameter!.value * 100)
        levelLabel.text = "\(Int(levelStepper.value)) %"
        
        drySwitch.isOn = dryMixParameter!.value > 0.5
        synthSwitch.isOn = synthParameter!.value > 0.5
        
        //legatoSwitch.isOn = midiLegatoParameter!.value > 0.5
        
        speedSlider.value = speedParameter!.value
        
        defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        showKeyboardSwitch.isOn = (defaults?.bool(forKey: "showMidiKeyboard"))!
        showTouchSwitch.isOn = (defaults?.bool(forKey: "showTouch"))!
        
        stereoModeLabel.text = stereoParameter?.valueStrings?[Int(stereoParameter?.value ?? 0)]
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destinationViewController.
     // Pass the selected object to the new view controller.
        
        switch segue.identifier {
        case "showReverb":
            let vc = segue.destination as! AuSettingsTableViewController
            vc.settings = ["0","1"]
            vc.showPresets(true)
            vc.title = "Reverb Settings"
            vc.audioUnit = reverbAudioUnit
        case "showMidi":
            let vc = segue.destination as! AuSettingsTableViewController
            vc.title = "MIDI Settings"
            vc.showPresets(false)
            vc.settings = ["keycenter_cc", "keycenter_cc_offset","keyquality_cc", "keyquality_cc_offset", "nvoices_cc","inversion_cc","midi_rx_pc", "midi_tx_harm","midi_tx_mel"]
            vc.audioUnit = globalAudioUnit
            
        default:
            break
        }
        
     }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")

        switch (cell.reuseIdentifier)
        {
        case "recordMode":
            let camera = (defaults?.bool(forKey: "cameraEnable") ?? false)
            let video = (defaults?.bool(forKey: "recordVideo") ?? false)
            var mode = "Audio Only"
            if (video && !camera)
            {
                mode = "Screen + Audio"
            }
            else if (video && camera)
            {
                mode = "Screen + Video"
            }
            cell.detailTextLabel?.text = mode
            
            cell.imageView?.image = UIImage(named: "circle.fill")?.withRenderingMode(.alwaysTemplate)
            
        case "showReverb":
            cell.isUserInteractionEnabled = (reverbAudioUnit != nil)
            cell.textLabel?.isEnabled = cell.isUserInteractionEnabled
        case "showInput":
            cell.isUserInteractionEnabled = (interfaceDelegate?.getInputViewController() != nil)
            cell.textLabel?.isEnabled = cell.isUserInteractionEnabled
        case "recordScreen":
            let enable = (defaults?.bool(forKey: "recordVideo") ?? false)
            cell.accessoryType = enable ? .checkmark : .none
        case "bgMode":
            let bgmode = (defaults?.bool(forKey: "bgModeEnable") ?? false)
            cell.accessoryType = bgmode ? .checkmark : .none
        default:
            break
        }
        
        return cell
    }
     
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath)
        let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        switch (cell?.reuseIdentifier)
        {
        case "showHarmony":
            self.performSegue(withIdentifier: "showHarmony", sender: self)
        case "showReverb":
            self.performSegue(withIdentifier: "showReverb", sender: self)
        case "showInput":
            let vc = interfaceDelegate?.getInputViewController()
            if (vc != nil)
            {
                self.show(vc!, sender: self)
            }
            break
        case "showFiles":
            let vc = interfaceDelegate?.getFilesViewController()
            if (vc != nil)
            {
                self.show(vc!, sender: self)
            }
            break
        case "showBtMidi":
            let btMidiViewController = CABTMIDICentralViewController()
            //btMidiViewController.view.backgroundColor = UIColor.black

            self.show(btMidiViewController, sender: self)
        case "stereoMode":
            if (stereoParameter?.maxValue == stereoParameter?.value)
            {
                stereoParameter?.value = 0
            }
            else
            {
                stereoParameter?.value = (stereoParameter?.value ?? 0) + 1
            }
            stereoModeLabel.text = stereoParameter?.valueStrings?[Int(stereoParameter?.value ?? 0)]

        case "recordMode":
            let screen = defaults?.bool(forKey: "recordVideo") ?? false
            let camera = defaults?.bool(forKey: "cameraEnable") ?? false
            
            if (screen && !camera)
            {
                defaults?.set(true, forKey: "cameraEnable")
            }
            else if (screen && camera)
            {
                defaults?.set(false, forKey: "recordVideo")
                defaults?.set(false, forKey: "cameraEnable")
            }
            else
            {
                defaults?.set(true, forKey: "recordVideo")
                defaults?.set(false, forKey: "cameraEnable")
            }
            //cell?.accessoryType = enable ? .checkmark : .none
            self.tableView.reloadData()
            
        case "aboutLink":
            let svc = SFSafariViewController(url: URL(string: "http://www.harmonizr.com/help")!)
            present(svc, animated: true, completion: nil)
        case "bgMode":
            let explain = "Background mode allows Harmonizr to run while you're using other apps, " +
                    "such as MIDI controllers, or if you want to use Harmonizr as an Inter-App Audio effect.  " +
                    "Leaving Backround mode on will decrease battery life."
                
            
            let bgmode = !(defaults?.bool(forKey: "bgModeEnable") ?? false)
            if (bgmode)
            {
                let alert = UIAlertController(title: "Background Mode On", message: explain, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                self.present(alert, animated: true)
                cell?.accessoryType = .checkmark
            }
            else
            {
                let alert = UIAlertController(title: "Background Mode Off", message: explain, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                self.present(alert, animated: true)
                cell?.accessoryType = .none
            }
        
            
            defaults?.set(bgmode, forKey: "bgModeEnable")
            self.tableView.reloadData()
        default:
            break;
        }
    }
    
    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        print("accessory: \(indexPath)")
    }
    @IBAction func drySwitch(_ sender: UISwitch) {
        dryMixParameter!.value = sender.isOn ? 1 : 0
    }
    
    @IBAction func synthSwitch(_ sender: UISwitch) {
        synthParameter!.value = sender.isOn ? 1 : 0
    }
    
//    @IBAction func legatoSwitch(_ sender: UISwitch) {
//        midiLegatoParameter!.value = sender.isOn ? 1 : 0
//    }
    
    @IBAction func harmonyLevel(_ sender: UIStepper) {
        hgainParameter!.value = AUValue(sender.value / 100)
        levelLabel.text = "\(Int(sender.value))%"
    }
    @IBAction func corrEnable(_ sender: UISwitch) {
        autoParameter!.value = sender.isOn ? 1 : 0
    }
    @IBAction func corrStrength(_ sender: UIStepper) {
        autoStrengthParameter!.value = AUValue(sender.value / 100)
        corrLabel.text = "\(Int(sender.value)) %"
    }
    @IBAction func baseTuning(_ sender: UIStepper) {
        tuningParameter!.value = AUValue(sender.value)
        
        tuningLabel.text = "\(tuningParameter!.value) Hz"
    }
    @IBAction func setThreshold(_ sender: UIStepper) {
        threshParameter!.value = AUValue(sender.value)
        threshLabel.text = "\(threshParameter!.value)"
    }
    @IBAction func setSpeed(_ sender: UISlider) {
        speedParameter!.value = pow(2, -5*(1-AUValue(sender.value)))
    }
    @IBAction func toggleKeyboard(_ sender: UISwitch) {
        defaults?.set(sender.isOn, forKey: "showMidiKeyboard")
    }
    
    @IBAction func showTouch(_ sender: UISwitch) {
        defaults?.set(sender.isOn, forKey: "showTouch")
    }
    
}


class ConfigDetailViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

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

}
