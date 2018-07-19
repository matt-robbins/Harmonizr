//
//  LabelButton.swift
//  iOSHarmonizerFramework
//
//  Created by Matthew E Robbins on 7/14/18.
//

import UIKit

class LabelButton: UIButton {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    var titleText: String = "" {
        didSet {
            setTitleText(titleText)
        }
    }
    
    override func layoutSubviews() {
        if (titleLabel != nil)
        {
            titleLabel!.numberOfLines = 0
            //titleLabel!.adjustsFontSizeToFitWidth = true
            titleLabel!.textAlignment = .center
            
            let factor = max(0.01, frame.height / (1.5*titleLabel!.font.pointSize), frame.width)
            //print("factor = \(factor)")
            if (factor < 1)
            {
                titleLabel!.transform = CGAffineTransform(scaleX: factor, y: factor)
            }
            else {
                titleLabel!.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }
        }
        
        setTitleColor(.cyan, for: UIControlState())
        setTitleColor(.white, for: .disabled)
        showsTouchWhenHighlighted = true
        
        super.layoutSubviews()
    }
    
    func setTitleText(_ label: String)
    {
        var newTitle = label
        if (isEnabled)
        {
            newTitle += "*"
        }
        
        setTitle(newTitle, for: UIControlState())
    }
    
    override var isEnabled: Bool {
        didSet {
            setTitleText(titleText)
        }
    }

}
