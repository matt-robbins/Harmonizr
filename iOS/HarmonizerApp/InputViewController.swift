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
        
        let session = AVAudioSession.sharedInstance()
        
        if (tableView === inputTable)
        {
            do {
                try session.setPreferredInput(data[row])
            }
            catch {
                print("oopsie!")
            }
            
            refresh()
            
            updateGainSlider()
            
        }
        if (tableView === inputDataSourceTable)
        {
            print("setting data source")
            do {
                try session.preferredInput?.setPreferredDataSource(dataSources[row])
            }
            catch {
                print("unable to set data source!")
            }
        }
        
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
        inputDataSourceTable.delegate = self
        inputDataSourceTable.dataSource = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: .AVAudioSessionRouteChange, object: AVAudioSession.sharedInstance())
        
        refresh()
        
        updateGainSlider()
        
        //self.tableView(self.tableView, didSelectRowAt: indexPath)
    }
    
    private func refresh()
    {
        DispatchQueue.main.async {
            
            let session = AVAudioSession.sharedInstance()
            
            var current_row = 0
            var current_source_ix = 0
            
            self.data = [AVAudioSessionPortDescription]()
            self.dataSources = [AVAudioSessionDataSourceDescription]()
            
            for s in session.availableInputs! {
                
                self.data.append(s)
                
                if (s.portName == session.currentRoute.inputs.first?.portName)
                {
                    current_row = self.data.index(of: s)!
                    
                    if ((s.dataSources) != nil)
                    {
                        for sr in (s.dataSources)!
                        {
                            self.dataSources.append(sr)
                            
                            if (sr.dataSourceName == s.selectedDataSource?.dataSourceName)
                            {
                                current_source_ix = self.dataSources.index(of: sr)!
                            }
                        }
                    }
                }
            }
            
            self.inputTable.reloadData()
            self.inputDataSourceTable.reloadData()
            
            var indexPath = IndexPath(row: current_source_ix, section: 0)
            self.inputDataSourceTable.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
            
            indexPath = IndexPath(row: current_row, section: 0)
            self.inputTable.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
        }
    }
    
    private func updateGainSlider()
    {
        DispatchQueue.main.async {
            let session = AVAudioSession.sharedInstance()
            self.inputGainSlider.isEnabled = session.isInputGainSettable
            if (session.isInputGainSettable)
            {
                self.inputGainSlider.value = session.inputGain
            }
        }
    }
    
    @objc private func handleRouteChange()
    {
        refresh()
        updateGainSlider()
    }
}

