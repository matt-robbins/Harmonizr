//
//  HarmTableViewCell.swift
//  Harmonizer
//
//  Created by Matthew E Robbins on 6/18/18.
//

import UIKit

@IBDesignable
class Led: UIView {
    override func awakeFromNib() {
        layer.backgroundColor = UIColor.darkGray.cgColor
        layer.shadowColor = tintColor.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 5
        layer.cornerRadius = 2.5
        layer.shadowOpacity = 0.0
    }
    
    func power(on: Bool) {
        layer.backgroundColor = on ? tintColor.cgColor : UIColor.darkGray.cgColor
        layer.shadowOpacity = on ? 1.0 : 0.0
    }
}

class HarmTableViewCell: UITableViewCell {

    var led = Led()
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
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
        led.power(on: selected)
        
        // Configure the view for the selected state
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        //textLabel!.textColor = highlighted ? tintColor : UIColor.white
    }
}
