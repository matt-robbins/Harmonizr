//
//  InputViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 2/10/18.
//

//
//  InputViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 11/15/17.
//

import Foundation
import UIKit
import AudioToolbox
import AVFoundation

public class InputViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    //MARK: Properties
    
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var inputTable: UITableView!
    var data: [AVAudioSessionPortDescription] = [AVAudioSessionPortDescription]()
    
    
    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //MARK: UITableView protocol
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    public func tableView(_ tableView: UITableView, numberOfSections section: Int) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.textLabel?.text = data[indexPath.row].portName
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setPreferredInput(data[row])
        }
        catch {
            print("oopsie!")
        }
        
        print(row)
        return
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        inputTable.delegate = self
        inputTable.dataSource = self
        
        let session = AVAudioSession.sharedInstance()
        
        var current_row = 0
        
        for s in session.availableInputs! {
            data.append(s)
            if (s == session.preferredInput)
            {
                current_row = data.index(of: s)!
            }
            //
        }
        self.inputTable.reloadData()
        
        let indexPath = IndexPath(row: current_row, section: 0);
        self.inputTable.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
        //self.tableView(self.tableView, didSelectRowAt: indexPath)
    }
}

