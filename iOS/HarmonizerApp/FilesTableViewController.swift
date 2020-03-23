//
//  FilesTableViewController.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 3/22/20.
//

import UIKit
import AVKit

class FilesTableViewController: UITableViewController {
    var count = 0
    var contents:[String]? = nil
    var recordingURL:URL!
    var DocumentsDirectory:URL!
    var audioEngine:AudioEngine2?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
        
        DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
        recordingURL = DocumentsDirectory.appendingPathComponent("recordings")
        
        if !FileManager.default.fileExists(atPath: recordingURL.path) {
            do {
                try FileManager.default.createDirectory(atPath: recordingURL.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print(error.localizedDescription);
            }
        }
        
        contents = getFileListByDate()
        count = contents?.count ?? 0
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return count
    }

    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "file", for: indexPath) as! FilesTableViewCell

        // Configure the cell...
        cell.recordingURL = recordingURL
        cell.parentController = self
        cell.file = contents?[indexPath.row] ?? "??"
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        do {
            let player = try AVAudioPlayer(contentsOf: recordingURL.appendingPathComponent(contents?[indexPath.row] ?? ""))
            print("playing!")
            player.play()
        }
        catch {
            print(error.localizedDescription)
        }
    }
    
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            
            if (contents != nil)
            {
                do {
                    try FileManager.default.removeItem(at: recordingURL.appendingPathComponent(contents![indexPath.row]))
                }
                catch {
                    print(error.localizedDescription)
                }
            }
            
            contents = getFileListByDate()
            
            count = contents?.count ?? 0
            
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    
    func getFileList() -> [String] {
        var stuff:[String]!
        do {
            try stuff = FileManager.default.contentsOfDirectory(atPath: recordingURL.path)
        } catch {
            print(error.localizedDescription)
            return []
        }
        return stuff
    }
    
    func getFileListByDate() -> [String] {
        if let urlArray = try? FileManager.default.contentsOfDirectory(at: recordingURL,
           includingPropertiesForKeys: [.contentModificationDateKey],
           options:.skipsHiddenFiles)
        {
            return urlArray.map { url in
                    (url.lastPathComponent, (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date.distantPast)
                }
                .sorted(by: { $0.1 > $1.1 }) // sort descending modification dates
                .map { $0.0 } // extract file names

        } else {
            return []
        }
    }

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

}
