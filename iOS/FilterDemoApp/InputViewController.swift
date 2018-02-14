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
    @IBOutlet weak var inputDataSourceTable: UITableView!
    @IBOutlet weak var inputGainSlider: UISlider!
    
    var data: [AVAudioSessionPortDescription] = [AVAudioSessionPortDescription]()
    var dataSources: [AVAudioSessionDataSourceDescription] = [AVAudioSessionDataSourceDescription]()
    
    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    //MARK: UITableView protocol
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if (tableView === inputTable)
        {
            return data.count
        }
        
        if (tableView === inputDataSourceTable)
        {
            return dataSources.count
        }
        
        fatalError("gaaaaa!")
    }
    
    public func tableView(_ tableView: UITableView, numberOfSections section: Int) -> Int {
        return 1
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if (tableView === inputTable)
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            
            cell.textLabel?.text = data[indexPath.row].portName
            return cell
        }
        if (tableView === inputDataSourceTable)
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "dataSourceCell", for: indexPath)
            
            cell.textLabel?.text = dataSources[indexPath.row].dataSourceName
            return cell
        }
        
        fatalError("gaaaa!")
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = (indexPath as NSIndexPath).row
        
        if (tableView === inputTable)
        {
            let session = AVAudioSession.sharedInstance()
            do {
                try session.setPreferredInput(data[row])
            }
            catch {
                print("oopsie!")
            }
            
            updateGainSlider()
//            dataSources = AVAudioSession.sharedInstance().inputDataSources?
//
//            if (dataSources != nil)
//            {
//                self.inputDataSourceTable.reloadData()
//            }
        }
        
        print(row)
        return
    }
    
    //MARK: Actions
    
    @IBAction func gainChanged(_ sender: UISlider) {
        do {
            try AVAudioSession.sharedInstance().setInputGain(sender.value)
        }
        catch {
            
        }
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
        
        updateGainSlider()
        
        let indexPath = IndexPath(row: current_row, section: 0);
        self.inputTable.selectRow(at: indexPath, animated: false, scrollPosition: UITableViewScrollPosition.none)
        //self.tableView(self.tableView, didSelectRowAt: indexPath)
    }
    
    
    private func updateGainSlider()
    {
        let session = AVAudioSession.sharedInstance()
        self.inputGainSlider.isEnabled =  session.isInputGainSettable
        if (session.isInputGainSettable)
        {
            inputGainSlider.value = session.inputGain
        }
    }
}

