//
//  ConfigDetailViewController.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 6/20/18.
//

import UIKit
import SwiftUI
import SafariServices
import CoreAudioKit



class SettingsDynamicViewController: UITableViewController {
    
    var defaults: UserDefaults?
    var reverbAudioUnit: AUAudioUnit?
    var interfaceDelegate: InterfaceDelegate?
    var paramTree: AUParameterTree?
    
    enum cellType {
        case link
        case param
        case binary
        case other
        case choices
    }
    
    struct cellDescriptor {
        var type: cellType
        var name: String
        var dname: String? = nil
        var action: (() -> Void)? = nil
        var choices: [String]? = nil
    }
    
    struct sectionDescriptor {
        var name: String?
        var cells: [cellDescriptor]
    }
    

    var table_cells: [sectionDescriptor] = []
    
    
    func showBtMidi() {
        let btMidiViewController = CABTMIDICentralViewController()
        self.show(btMidiViewController, sender: self)
    }
    
    func showInput() {
        let vc = interfaceDelegate?.getInputViewController()
        if (vc != nil)
        {
            self.show(vc!, sender: self)
        }
    }
    
    func showFiles() {
        let vc = interfaceDelegate?.getFilesViewController()
        if (vc != nil)
        {
            self.show(vc!, sender: self)
        }
    }
    
    func showWeb() {
        let svc = SFSafariViewController(url: URL(string: "https://www.harmonizr.com/help")!)
        present(svc, animated: true, completion: nil)
    }
    
    func bgModeAlert() {
        let explain = "Background mode allows Harmonizr to run while you're using other apps, " +
                "such as MIDI controllers, or if you want to use Harmonizr as an Inter-App Audio effect.  " +
                "Leaving Backround mode on will decrease battery life."
    
        let state_text = defaults?.bool(forKey: "bgModeEnable") ?? false ? "On" : "Off"
        let alert = UIAlertController(title: "Background Mode \(state_text)", message: explain, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
        self.present(alert, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        paramTree = globalAudioUnit?.parameterTree
        defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        table_cells = [
            sectionDescriptor(name: "Harmony", cells:
            [
                cellDescriptor(type: .link, name: "showHarmony", dname: "Edit Preset"),
                cellDescriptor(type: .param, name: "gate_thresh"),
                cellDescriptor(type: .param, name: "speed"),
                cellDescriptor(type: .param, name: "h_gain"),
                cellDescriptor(type: .param, name: "auto"),
                cellDescriptor(type: .param, name: "auto_strength"),
                cellDescriptor(type: .param, name: "threshold"),
                cellDescriptor(type: .param, name: "tuning"),
                cellDescriptor(type: .param, name: "dry_mix"),
                cellDescriptor(type: .param, name: "stereo_mode"),
            ]),
            sectionDescriptor(name: "System", cells:
            [
                cellDescriptor(type: .link, name: "showMidi", dname: "MIDI Settings"),
                cellDescriptor(type: .link, name: "btmidi", dname: "Bluetooth MIDI", action: showBtMidi),
                cellDescriptor(type: .link, name: "showReverb", dname: "Reverb Settings"),
                cellDescriptor(type: .link, name: "input", dname: "Audio Input", action: showInput),
                cellDescriptor(type: .binary, name: "bgModeEnable", dname: "Background Mode", action: bgModeAlert)
                
            ]),
            sectionDescriptor(name: "Display", cells:
            [
                cellDescriptor(type: .binary, name: "showMidiKeyboard", dname: "Show Keyboard"),
                cellDescriptor(type: .binary, name: "showTouch", dname: "Show Touch Points"),
                cellDescriptor(type: .binary, name: "doneTutorial", dname: "Show Tutorial On Start"),
                cellDescriptor(type: .link, name: "about", dname: "About Harmonizr (Web)", action: showWeb),
            ]),
            sectionDescriptor(name: "Recording", cells:
            [
                cellDescriptor(type: .binary, name: "recordVideo", dname: "Record Screen"),
                cellDescriptor(type: .binary, name: "cameraEnable", dname: "Screen + Camera"),
                cellDescriptor(type: .link, name: "showFiles", dname: "Audio Recordings", action: showFiles)
            ])
        ]
    }
    
    
     // MARK: - Navigation
     
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
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
            vc.settings = ["keycenter_cc", "midi_vel_ign", "keycenter_cc_offset","keyquality_cc", "keyquality_cc_offset", "nvoices_cc","inversion_cc","midi_rx_pc", "midi_tx_harm","midi_tx_mel"]
            vc.audioUnit = globalAudioUnit
            
        default:
            break
        }
     }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return table_cells[section].name
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return table_cells.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return table_cells[section].cells.count
    }
    
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        
        let descriptor = table_cells[indexPath.section].cells[indexPath.row]
        
        switch (descriptor.type) {
        case .link, .other:
            let cell = tableView.dequeueReusableCell(withIdentifier: "link", for: indexPath) as! LinkTableViewCell
            
            cell.contentConfiguration = UIHostingConfiguration {
                HStack {
                    Text(descriptor.dname ?? descriptor.name)
                }
            }
            
            cell.accessoryType = .disclosureIndicator
            return cell
            
        case .param:
            let cell = tableView.dequeueReusableCell(withIdentifier: "auparameter", for: indexPath) as! AuParameterTableViewCell
            cell.param = paramTree?.value(forKey: descriptor.name) as? AUParameter
            cell.parentTable = self.tableView
            cell.selectionStyle = .none
            return cell
            
        case .binary:
            let cell = tableView.dequeueReusableCell(withIdentifier: "generic", for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                HStack {
                    Text(descriptor.dname ?? descriptor.name)
                }
            }
            let check = defaults?.bool(forKey: descriptor.name) ?? false
            cell.accessoryType = check ? .checkmark : .none
            
            return cell
        case .choices:
            let cell = tableView.dequeueReusableCell(withIdentifier: "generic", for: indexPath)
            cell.contentConfiguration = UIHostingConfiguration {
                HStack {
                    Text(descriptor.dname ?? descriptor.name)
                }
            }
            return cell
        }
        
    }
     
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let cell = tableView.cellForRow(at: indexPath)
        //let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
        let descriptor = table_cells[indexPath.section].cells[indexPath.row];
        switch (descriptor.type)
        {
        case .link:
            if let action = descriptor.action {
                action()
            }
            else {
                performSegue(withIdentifier: descriptor.name, sender: nil)
            }
        case .binary:
            
            let val = defaults?.bool(forKey: descriptor.name) ?? false
            defaults?.set(!val, forKey: descriptor.name)
            cell?.accessoryType = !val ? .checkmark : .none
            
            if let action = descriptor.action {
                action()
            }
        case .other:
            break
        default:
            break
        }
       
    }
}

