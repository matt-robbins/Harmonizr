//
//  HarmTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 6/18/18.
//

import UIKit

class HarmTableViewCell: UITableViewCell {

    var led = UIView()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        led.layer.backgroundColor = UIColor.darkGray.cgColor
        led.layer.shadowColor = tintColor.cgColor
        led.layer.shadowOffset = CGSize(width: 0, height: 0)
        led.layer.shadowRadius = 5
        led.layer.cornerRadius = 2.5
        led.layer.shadowOpacity = 0.0
        
        led.frame = CGRect(x: 0, y: 0, width:5, height:5)
        
        self.accessoryView = led
        
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
        print(selected)
        if (selected)
        {
            led.layer.backgroundColor = tintColor.cgColor
            led.layer.shadowOpacity = 1.0
        }
        else
        {
            led.layer.backgroundColor = UIColor.darkGray.cgColor
            led.layer.shadowOpacity = 0.0
        }
        
        // Configure the view for the selected state
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        //textLabel!.textColor = highlighted ? tintColor : UIColor.white
    }
}
