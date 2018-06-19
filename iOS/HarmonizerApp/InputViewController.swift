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
    @IBOutlet weak var inputGainSlider: UISlider!
    
    weak var tableGainSlider: UISlider?
    
    var data: [AVAudioSessionPortDescription] = [AVAudioSessionPortDescription]()
    var dataSources: [AVAudioSessionDataSourceDescription] = [AVAudioSessionDataSourceDescription]()
    
    
    @IBAction func done(_ sender: Any) {
        self.dismiss(animated: false, completion: nil)
    }
    
    //MARK: UITableView protocol
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        print(section)
        switch section {
        case 0:
            return data.count
        case 2:
            return max(dataSources.count,0)
        default:
            return 1
        }
    }
    
    public func tableView(_ tableView: UITableView,
                   titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 2:
            return "Option"
        case 1:
            return "Gain"
        default:
            return "Source"
        }
    }
    
    public func numberOfSections(in tableView: UITableView) -> Int {
        return 3
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if (indexPath.section == 0)
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
            
            cell.textLabel?.text = data[indexPath.row].portName
            return cell
        }
        if (indexPath.section == 2)
        {
            let cell = tableView.dequeueReusableCell(withIdentifier: "dataSourceCell", for: indexPath)
            if (dataSources.count == 0)
            {
                cell.detailTextLabel?.text = "oops"
                cell.isUserInteractionEnabled = false
            }
            else
            {
                cell.isUserInteractionEnabled = true
                cell.textLabel?.text = dataSources[indexPath.row].dataSourceName
            }
            return cell
        }
        
        if (indexPath.section == 1)
        {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "gainCell", for: indexPath) as? AUParameterTableViewCell  else {
                fatalError("The dequeued cell is not an instance of AUParameterTableViewCell.")
            }
            
            if (cell.valueSlider != nil)
            {
                cell.valueSlider.value = AVAudioSession.sharedInstance().inputGain
            }
            return cell
        }
        
        fatalError("gaaaa!")
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        let session = AVAudioSession.sharedInstance()
        
        if (indexPath.section == 0)
        {
            do {
                try session.setPreferredInput(data[indexPath.row])
            }
            catch {
                print("oopsie!")
            }
            
            refresh()
        }
        if (indexPath.section == 2)
        {
            do {
                try session.preferredInput?.setPreferredDataSource(dataSources[indexPath.row])
            }
            catch {
                print("unable to set data source!")
            }
            refresh()
        }
        //
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
        inputTable.isScrollEnabled = false
        inputTable.tableFooterView = UIView()
        inputTable.allowsMultipleSelection = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange), name: .AVAudioSessionRouteChange, object: AVAudioSession.sharedInstance())
        
        refresh()
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
            //self.inputDataSourceTable.reloadData()
            
            var indexPath = IndexPath(row: current_source_ix, section: 2)
            self.inputTable.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
            
            indexPath = IndexPath(row: current_row, section: 0)
            self.inputTable.selectRow(at: indexPath, animated: true, scrollPosition: UITableViewScrollPosition.none)
        }
    }
    
    @objc private func handleRouteChange()
    {
        refresh()
    }
}

