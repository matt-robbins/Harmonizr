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
    
    var alayer = CALayer()
    
    @IBInspectable var keycenter: Int = 0
    
    @IBInspectable var cornerRadius: CGFloat = 6 {
        didSet {
            alayer.cornerRadius = cornerRadius
            layer.cornerRadius = cornerRadius
        }
    }
    
    @IBInspectable var highlightColor: CGColor = UIColor.cyan.cgColor {
        didSet {
            if (isSelected)
            {
                alayer.borderColor = highlightColor
                alayer.shadowColor = highlightColor
            }
        }
    }
    
    @IBInspectable var borderWidth: CGFloat = 3
    @IBInspectable var shadowRadius: CGFloat = 8
    
    func enableBorder(_ border: Bool)
    {
        if (border)
        {
            alayer.borderWidth = borderWidth
            alayer.shadowRadius = shadowRadius
        }
        else
        {
            alayer.borderWidth = 0
            alayer.shadowRadius = 0
        }
    }
    
    @IBInspectable var border: Bool = true {
        didSet {
            enableBorder(border)
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
        
        //setTitleColor(.white, for: .disabled)
        
        layer.addSublayer(alayer)
                
        cornerRadius = frame.height/10
        borderWidth = frame.height/20
        alayer.backgroundColor = UIColor.clear.cgColor //layer.backgroundColor
        alayer.shadowColor = highlightColor
        alayer.cornerRadius = cornerRadius
        alayer.borderWidth = borderWidth
        alayer.opacity = 0.5
        alayer.borderColor = UIColor.gray.cgColor
        alayer.shadowOffset = CGSize(width: 0, height: 0)
        alayer.shadowRadius = shadowRadius
        layer.masksToBounds = false
        alayer.masksToBounds = false
        //showsTouchWhenHighlighted = true
        
        self.titleLabel!.minimumScaleFactor = 0.1
        isSelected = false
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
            
            let factor = max(0.01, min(frame.height / (1.5*titleLabel!.font.pointSize), frame.width / (1.5*titleLabel!.intrinsicContentSize.width)))
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
            if (isHighlighted || isSelected)
            {
                cornerRadius = frame.width/10
                borderWidth = frame.width/15
            }
            else
            {
                cornerRadius = frame.width/10
                borderWidth = frame.width/20
            }
            enableBorder(border)
            alayer.frame = layer.bounds
            
            //configure()
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
            CATransaction.begin()
            switch isHighlighted {
            case true:
                CATransaction.setAnimationDuration(0.05)
                alayer.borderColor = highlightColor
                alayer.borderWidth = frame.width/15
                alayer.opacity = 1.0
                alayer.shadowOpacity = 1.0
                superview?.bringSubview(toFront: self)
            case false:
                
                CATransaction.setAnimationDuration(0.2)
                alayer.borderWidth = frame.width/20
                if (!isSelected)
                {
                    alayer.borderColor = UIColor.darkGray.cgColor
                    alayer.shadowOpacity = 0.0
                    alayer.opacity = 1.0
                }
            }
            CATransaction.commit()
        }
    }
    
    override var isSelected: Bool {
        didSet {
            alayer.removeAllAnimations()
            CATransaction.begin()
            switch isSelected {
            case true:
                CATransaction.setAnimationDuration(0.05)
                alayer.shadowColor = highlightColor
                alayer.borderColor = highlightColor
                alayer.shadowOpacity = 1.0
                alayer.opacity = 1.0
                alayer.borderWidth = frame.width/20
                superview?.bringSubview(toFront: self)
            case false:
                CATransaction.setAnimationDuration(0.2)
                alayer.borderColor = UIColor.darkGray.cgColor
                alayer.borderWidth = frame.width/20
                alayer.shadowOpacity = 0.0
                alayer.opacity = 1.0
            }
            CATransaction.commit()
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
                alayer.shadowColor = UIColor.red.cgColor
                alayer.shadowOpacity = 1.0
                superview?.bringSubview(toFront: self)
            case false:
                isSelected = isSelected && true
                //setTitleColor(.black, for: UIControlState())
            }
        }
    }
}
