//
//  VUMeter.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 7/23/20.
//

import Foundation
import UIKit

@IBDesignable
class VUMeter: UIView {
    var colors = [UIColor.green, UIColor.yellow, UIColor.red]
    
    override func awakeFromNib()
    {
        for ix in 0...2
        {
            let led = CALayer()
            
            led.backgroundColor = UIColor.init(white: 1.0, alpha: 0.2).cgColor
            led.borderWidth = 0
            led.cornerRadius = 2
            
            led.shadowColor = colors[ix].cgColor
            led.shadowOpacity = 0.0
            led.shadowRadius = 5.0
            led.shadowOffset = CGSize(width: 0, height: 0)
            
            layer.addSublayer(led)
        }
    }
    
    override func layoutSublayers(of layer: CALayer) {
        let sublayers = layer.sublayers!
        let ledheight = layer.frame.width / 2
        var count = 0
        let pad: CGFloat = 5
        for ix in 0...2
        {
            let xpos = layer.frame.width/4
            let width: CGFloat = ledheight
            let ypos = layer.frame.height * CGFloat(ix+1)/4 - ledheight/2
            
            sublayers[count].frame = CGRect(x: xpos, y: ypos, width: width, height: CGFloat(ledheight))
            sublayers[count].cornerRadius = ledheight / 2
            sublayers[count].borderWidth = 0
            count += 1
        }
        layer.transform = CATransform3DMakeScale(1, -1, 1);
    }
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public func set_gain(gain: Float)
    {
        let sublayers = layer.sublayers!
        
        let gains = [0.02, 0.1, 0.5]
        for ix in 0...sublayers.count-1
        {
            if (CGFloat(gain) > CGFloat(gains[ix]))
            {
                sublayers[ix].backgroundColor = colors[ix].cgColor
                sublayers[ix].shadowOpacity = 1.0
            }
            else
            {
                sublayers[ix].backgroundColor = UIColor.init(white: 1.0, alpha: 0.2).cgColor
                sublayers[ix].shadowOpacity = 0.0
            }
        }
    }
    
}
