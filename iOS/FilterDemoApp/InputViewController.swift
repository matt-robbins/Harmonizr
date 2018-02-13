//
//  InputViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 2/10/18.
//

//
//  ReverbViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 11/15/17.
//

import Foundation
import UIKit
import AudioToolbox
import AVFoundation

public class InputViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet weak var doneButton: UIButton!
    @IBOutlet weak var inputTable: UITableView!
    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    var data: [AVAudioSessionPortDescription] = [AVAudioSessionPortDescription]()
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    public func tableView(_ tableView: UITableView,
                   cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        
        cell.textLabel?.text = data[indexPath.row].portName
        return cell
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        print(row)
    }
    
    public override func viewDidLoad()
    {
        super.viewDidLoad()
        
        let session = AVAudioSession.sharedInstance()
        
        for s in session.availableInputs! {
            data.append(s)
            //
        }
        self.inputTable.reloadData()
    }
}

