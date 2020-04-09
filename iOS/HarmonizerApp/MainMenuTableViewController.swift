//
//  MainMenuTableViewController.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 3/23/20.
//

import UIKit
import CoreAudioKit

enum sectionHeader:Int {
    case controllers,bluetooth,backgroundmode
}

class MainMenuTableViewController: UITableViewController {

    let controllers = ["reverbController","inputController","filesController"]
    
    //let images = [UIImage(systemName: "dot.radiowaves.left.and.right"),UIImage(systemName: "mic")]
    var rootViewController:UIViewController!
    var audioEngine:AudioEngine2?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 3
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        let sh = sectionHeader(rawValue: section)
        switch (sh)
        {
        case .controllers:
            return controllers.count
        case .bluetooth:
            return 1
        case .backgroundmode:
            return 1
        default:
            return 0
        }
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "basic", for: indexPath)

        // Configure the cell...
        switch (sectionHeader(rawValue: indexPath.section))
        {
        case .controllers:
            guard let vc = self.storyboard?.instantiateViewController(withIdentifier: controllers[indexPath.row]) else {
                return cell
            }
            
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = vc.title
        case .bluetooth:
            cell.accessoryType = .disclosureIndicator
            cell.textLabel?.text = "Bluetooth MIDI interface..."
        case .backgroundmode:
            let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
            let bgmode = defaults?.bool(forKey: "bgModeEnable") ?? false
            cell.accessoryType = bgmode ? .checkmark : .none
            cell.textLabel?.text = "Enable Background Mode"
        default:
            cell.textLabel?.text = "???"
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch(sectionHeader(rawValue: indexPath.section))
        {
        case .controllers:
            guard let vc = self.storyboard?.instantiateViewController(withIdentifier: controllers[indexPath.row]) else { return }
            
            if (vc is ReverbViewController)
            {
                let rc = (vc as! ReverbViewController)
                rc.audioUnit = audioEngine?.reverbUnit
                self.show(rc, sender: self)
                return
            }
//            if (vc is FilesTableViewController)
//            {
//                (vc as! FilesTableViewController).audioEngine = audioEngine
//            }
            self.show(vc, sender: self)
            
        case .bluetooth:
            let btMidiViewController = CABTMIDICentralViewController()
            btMidiViewController.view.backgroundColor = UIColor.black

            self.show(btMidiViewController, sender: self)
        case .backgroundmode:
            let explain = "Background mode allows Harmonizr to run while you're using other apps, " +
                "such as MIDI controllers, or if you want to use Harmonizr as an Inter-App Audio effect.  " +
                "Leaving Backround mode on will decrease battery life."
            
            let defaults = UserDefaults(suiteName: "group.harmonizr.extension")
            let bgmode = !(defaults?.bool(forKey: "bgModeEnable") ?? false)
            if (bgmode)
            {
                let alert = UIAlertController(title: "Background Mode On", message: explain, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                self.present(alert, animated: true)
            }
            else
            {
                let alert = UIAlertController(title: "Background Mode Off", message: explain, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Okay", style: .default, handler: nil))
                self.present(alert, animated: true)
            }
        
            
            defaults?.set(bgmode, forKey: "bgModeEnable")
            self.tableView.reloadData()
            
        default:
            return
        }
    }

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
    }

}
