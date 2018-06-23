//
//  File.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 6/21/18.
//

import Foundation

class ConfigNavigationController: UINavigationController {
    
    weak var viewDelegate: HarmonizerAlternateViewDelegate?
    
    public var audioUnit: AUv3Harmonizer?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        print(self.viewControllers)
        self.viewControllers.first?.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @objc func done()
    {
        viewDelegate?.ShowMainView()
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
