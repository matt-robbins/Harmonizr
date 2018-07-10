//
//  HarmViewController.swift
//  iOSFilterDemoApp
//
//  Created by Matthew E Robbins on 11/15/17.
//

import Foundation

import UIKit
import CoreAudioKit

enum tags
{
    
}

@IBDesignable
class HarmButton: UIButton {
    
    @IBInspectable var keycenter: Int = 0
    
    @IBInspectable var cornerRadius: CGFloat = 0 {
        didSet {
            layer.cornerRadius = cornerRadius
        }
    }
    
    @IBInspectable var highlightColor: CGColor = UIColor.cyan.cgColor {
        didSet {
            if (isSelected)
            {
                layer.borderColor = highlightColor
                layer.shadowColor = highlightColor
            }
        }
    }
    
    func configure() {
        //backgroundColor = .white
        
        highlightColor = tintColor.cgColor
        if (backgroundColor == .white)
        {
            setTitleColor(.black, for: UIControlState())
        }
        else if (backgroundColor == .black)
        {
            setTitleColor(.white, for: UIControlState())
        }
        layer.shadowColor = highlightColor
        layer.cornerRadius = 4
        layer.borderWidth = 4
        layer.borderColor = UIColor.darkGray.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 0)
        layer.shadowRadius = 8
        layer.masksToBounds = false
        showsTouchWhenHighlighted = true
        
        self.titleLabel!.minimumScaleFactor = 0.1
        //self.titleLabel!.adjustsFontSizeToFitWidth = true
    }
    
    override func tintColorDidChange() {
        highlightColor = tintColor.cgColor
    }
    
    override func layoutSubviews() {

        if (titleLabel != nil)
        {
            titleLabel!.numberOfLines = 0
            //titleLabel!.adjustsFontSizeToFitWidth = true
            titleLabel!.textAlignment = .center
            
            let factor = min(frame.height / (1.5*titleLabel!.font.pointSize), frame.width / (1.5*titleLabel!.intrinsicContentSize.width))
            //print("factor = \(factor)")
            if (factor < 1)
            {
                titleLabel!.transform = CGAffineTransform(scaleX: factor, y: factor)
            }
            else {
                titleLabel!.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
            }
            //let font = titleLabel!.font
            //titleLabel!.font = UIFont(name: (font?.description)!, size: frame.height / 2)
        }
        
        super.layoutSubviews()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        // set other operations after super.init, if required
        self.configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        // set other operations after super.init if required
        self.configure()
    }
    
    override var isHighlighted: Bool {
        didSet {
            switch isHighlighted {
            case true:
                layer.borderColor = highlightColor
                layer.shadowOpacity = 1.0
                superview?.bringSubview(toFront: self)
            case false:
                if isSelected { return }
                layer.borderColor = UIColor.darkGray.cgColor
                layer.shadowOpacity = 0.0
            }
        }
    }
    
    override var isSelected: Bool {
        didSet {
            switch isSelected {
            case true:
                layer.shadowColor = highlightColor
                layer.borderColor = highlightColor
                layer.shadowOpacity = 1.0
                superview?.bringSubview(toFront: self)
            case false:
                layer.borderColor = UIColor.darkGray.cgColor
                layer.shadowOpacity = 0.0
            }
        }
    }
    
    override var isEnabled: Bool {
        didSet {
            switch isEnabled {
            case true:
                self.layer.opacity = 1
            case false:
                self.layer.opacity = 0.5
            }
        }
    }
    
    public var isBeingPlayed: Bool = false {
        didSet {
            switch isBeingPlayed {
            case true:
                //layer.borderColor = UIColor.red.cgColor
                //setTitleColor(.red, for: UIControlState())
                layer.shadowColor = UIColor.red.cgColor
                layer.shadowOpacity = 1.0
                superview?.bringSubview(toFront: self)
            case false:
                isSelected = isSelected && true
                //setTitleColor(.black, for: UIControlState())
            }
        }
    }
}
