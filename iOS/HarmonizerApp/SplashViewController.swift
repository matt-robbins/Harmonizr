//
//  SplashViewController.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 4/6/20.
//

import UIKit

class SplashViewController: UIViewController {

    @IBOutlet weak var splashImage: UIImageView!
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        UIView.animate(withDuration: 1.0, delay: 0, options: .curveEaseOut, animations: {
            self.splashImage.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
        }, completion: { finished in
          print("Napkins opened!")
        })
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
