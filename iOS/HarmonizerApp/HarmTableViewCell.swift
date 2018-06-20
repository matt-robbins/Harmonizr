//
//  HarmTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 6/18/18.
//

import UIKit

class HarmTableViewCell: UITableViewCell {

    var led = CALayer()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        led.backgroundColor = UIColor.darkGray.cgColor
        led.shadowColor = tintColor.cgColor
        led.shadowOffset = CGSize(width: 0, height: 0)
        led.shadowRadius = 5
        led.cornerRadius = 2.5
        led.shadowOpacity = 0.0
        
        led.frame = CGRect(x: 0, y: 0, width:5, height:5)
        
        layer.addSublayer(led)
        
        self.selectionStyle = UITableViewCellSelectionStyle.none
    }
    
    override func layoutSubviews() {
        led.frame = CGRect(x: layer.frame.width - 15, y: layer.frame.height/2 - 2.5, width:5, height:5)
        super.layoutSubviews()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        //super.setSelected(selected, animated: animated)
        
//        let v = UIView()
//        v.backgroundColor = tintColor
//        selectedBackgroundView = v
        
        if (selected)
        {
            led.backgroundColor = tintColor.cgColor
            led.shadowOpacity = 1.0
        }
        else
        {
            led.backgroundColor = UIColor.darkGray.cgColor
            led.shadowOpacity = 0.0
        }
        
        // Configure the view for the selected state
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        //textLabel!.textColor = highlighted ? tintColor : UIColor.white
    }
}
