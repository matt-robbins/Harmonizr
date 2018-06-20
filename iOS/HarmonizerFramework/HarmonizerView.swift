/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View for the FilterDemo audio unit. This lets the user adjust the filter cutoff frequency and resonance on an X-Y grid.
*/

import UIKit

/* 
    The `HarmonizerViewDelegate` protocol is used to notify a delegate (`HarmonizerViewController`)
 */
protocol HarmonizerViewDelegate: class {
    func harmonizerView(_ view: HarmonizerView, didChangeKeycenter keycenter: Float)
    func harmonizerView(_ view: HarmonizerView, touchIsDown touch: Bool)
    func harmonizerViewGetPitch(_ view: HarmonizerView) -> Float
    func harmonizerViewGetKeycenter(_ view: HarmonizerView) -> Float
}

class VerticallyCenteredTextLayer : CATextLayer {
    
    // REF: http://lists.apple.com/archives/quartz-dev/2008/Aug/msg00016.html
    // CREDIT: David Hoerl - https://github.com/dhoerl
    // USAGE: To fix the vertical alignment issue that currently exists within the CATextLayer class.
    
    override func draw(in ctx: CGContext) {
        let fontSize = self.fontSize
        let height = self.bounds.size.height
        let deltaY = (height-fontSize)/2 - fontSize/10
        
        ctx.saveGState()
        ctx.translateBy(x: 0.0, y: deltaY)
        super.draw(in: ctx)
        ctx.restoreGState()
    }
}

class GlowButton: VerticallyCenteredTextLayer {
    
    var keycenter: Int = 0
    var tintColor = UIColor.orange.cgColor {
        didSet {
            shadowColor = tintColor
            if (isSelected)
            {
                borderColor = tintColor
            }
        }
    }
    
    func configure() {
        fontSize = 14
        contentsScale = UIScreen.main.scale
        alignmentMode = kCAAlignmentCenter
        backgroundColor = UIColor.white.cgColor
        foregroundColor = UIColor.black.cgColor
        shadowColor = tintColor
        cornerRadius = 4
        borderWidth = 4
        borderColor = UIColor.darkGray.cgColor
        shadowOffset = CGSize(width: 0, height: 0)
        shadowRadius = 8
        masksToBounds = false
    }

    override init(layer: Any)
    {
        self.isSelected = false
        super.init(layer: layer)
    }
    
    override init() {
        self.isSelected = false
        super.init()
        configure()
    }
    
    required init?(coder aDecoder: NSCoder) {
        self.isSelected = false
        super.init(coder: aDecoder)
        
        // set other operations after super.init if required
        self.configure()
    }
    
    var isSelected: Bool {
        didSet {
            CATransaction.begin()
            
            if ( isSelected && isEnabled ) {
                CATransaction.setAnimationDuration(0.05)
                self.borderColor = tintColor
                self.shadowOpacity = 1.0
            }
            else {
                CATransaction.setAnimationDuration(0.2)
                self.borderColor = UIColor.darkGray.cgColor
                self.shadowOpacity = 0.0
            }
            CATransaction.commit()
        }
    }
    
    var isEnabled: Bool = true {
        didSet {
            opacity = isEnabled ? 1.0 : 0.5
        }
    }
}

class keycenterButton: GlowButton {
    
}

@IBDesignable
class HarmonizerView: UIView {
    // MARK: Properties

    var enable = 1
    
    var keycenter = 0
    
    var lastNote = -1
    
    var volumeStart: Float = 0.0
    var currGain: Float = 0.0
    
    var keybuttons = [GlowButton]()

    var containerLayer = CALayer()
    //var keysLayer = CALayer()

    var pulseAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
    var glowAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
    var redAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.backgroundColor))
    
    // The delegate to notify for keycenter changes
    weak var delegate: HarmonizerViewDelegate?

    var touchDown = false
    var currentKey = 0
    var currentTriad = -1
    
    func setSelectedNote(_ note: Float) {
        let n = keybuttons.count
        
        let curr_note = Int(round(note))

        if (curr_note == lastNote)
        {
            return
        }
        for j in 0...n-1 {
            CATransaction.begin()
            if (j % 12 == curr_note)
            {
                CATransaction.setAnimationDuration(0.05)
                keybuttons[j].shadowColor = UIColor.red.cgColor
                keybuttons[j].shadowOpacity = 1.0
            }
            else
            {
                CATransaction.setAnimationDuration(1.0)
                keybuttons[j].shadowOpacity = 0.0
                keybuttons[j].shadowColor = tintColor.cgColor
            }
            CATransaction.commit()
        }
        
        lastNote = curr_note
    }
    
    func setSelectedKeycenter(_ keycenter: Float)
    {
        let new_key = Int(keycenter)
        var root = new_key % 12
        let quality = new_key / 12
        
        if quality == 1 //relative major
        {
            root = (root + 3) % 12
        }
        var keynames = [String]()

        switch (root)
        {
        case 1,6:
            keynames = ["C", "D\u{266D}", "D", "E\u{266D}", "E", "F", "G\u{266D}","G","A\u{266D}", "A", "B\u{266D}", "C\u{266D}"]
        case 2:
            keynames = ["C", "C\u{266f}", "D", "D\u{266f}", "E", "F", "F\u{266f}","G","G\u{266f}", "A", "B\u{266D}", "B"]
        case 3:
            keynames = ["C", "D\u{266D}", "D", "E\u{266D}", "E", "F", "G\u{266D}","G","A\u{266D}", "A", "B\u{266D}", "B"]
        case 4,9,11:
            keynames = ["C", "C\u{266f}", "D", "D\u{266f}", "E", "F", "F\u{266f}","G","G\u{266f}", "A", "A\u{266f}", "B"]
        case 5,10:
            keynames = ["C", "D\u{266D}", "D", "E\u{266D}", "E", "F", "F\u{266f}","G","A\u{266D}", "A", "B\u{266D}", "B"]
        default:
            keynames = ["C", "C\u{266f}", "D", "D\u{266f}", "E", "F", "F\u{266f}","G", "A\u{266D}", "A", "B\u{266D}", "B"]
        }

        for key in 0...11
        {
            keybuttons[key].string = keynames[key]
        }
        for key in 0...35
        {
            if (keybuttons[key].isSelected)
            {
                keybuttons[key].isSelected = false
            }
        }
        
        keybuttons[new_key].isSelected = true
        currentKey = new_key
    }
    
    override func awakeFromNib() {
        // Create all of the CALayers
        let scale = UIScreen.main.scale
        print(layer.bounds.size)
        containerLayer.name = "container"
        containerLayer.anchorPoint = CGPoint.zero
        containerLayer.frame = CGRect(origin: CGPoint.zero, size: layer.bounds.size)
        containerLayer.backgroundColor = UIColor(white: 0.1, alpha: 1.0).cgColor
        containerLayer.bounds = containerLayer.frame
        containerLayer.contentsScale = scale
        layer.addSublayer(containerLayer)
        
        pulseAnimation.duration = 1
        pulseAnimation.fromValue = 1
        pulseAnimation.toValue = 0.4
        pulseAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
        pulseAnimation.speed = 3
        pulseAnimation.autoreverses = true
        pulseAnimation.repeatCount = .greatestFiniteMagnitude
        
        glowAnimation.duration = 1
        glowAnimation.fromValue = 1
        glowAnimation.toValue = 0
        glowAnimation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseOut)
        glowAnimation.speed = 1
        glowAnimation.autoreverses = false
        glowAnimation.repeatCount = 1
        
        for j in 0...2
        {            
            for i in 0...11
            {
                let keyLayer = GlowButton()
                keyLayer.tintColor = tintColor.cgColor
                keyLayer.contentsScale = UIScreen.main.scale
                let blackkeys = [1,3,6,8,10]
                
                if (j == 0)
                {
                    keyLayer.string = ""
                }
                else if (j == 1)
                {
                    keyLayer.string = "min"
                }
                else if (j == 2)
                {
                    keyLayer.string = "7"
                }
                
                keyLayer.fontSize = 18
                keyLayer.alignmentMode = kCAAlignmentCenter
                
                var bri = 1.0

                if blackkeys.contains(i) {
                    bri = 0.0
                }
                
                keyLayer.backgroundColor = UIColor(hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(bri), alpha: 1.0).cgColor
                keyLayer.foregroundColor = UIColor(hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(1-bri), alpha: 1.0).cgColor
                
                keyLayer.keycenter = 12*j + i
                keybuttons.append(keyLayer)

                containerLayer.addSublayer(keyLayer)
            }
        }
        
        layer.contentsScale = scale
    }
    
	/*
		This function positions all of the layers of the view.
		This method is also called when the orientation of the device changes
		and the view needs to re-layout for the new view size.
	 */
    
	override func layoutSublayers(of layer: CALayer) {        
        if layer === self.layer {
            // Disable implicit layer animations.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            containerLayer.bounds = layer.bounds
            //containerLayer.frame = layer.frame
            
            let spacing = containerLayer.frame.width / 12
            let keywidth = spacing * 0.95
            let keyoffset = (spacing - keywidth)/2
            
            var vspacing = layer.frame.height/3.2
            var keyheight = vspacing * 0.95
            
            if (keyheight > keywidth)
            {
                keyheight = keywidth
                vspacing = keyheight * 1.05
            }
            
            let blackkeys = [1,3,6,8,10]
            for j in 0...2 {
                for i in 0...11 {
                    var height = CGFloat(j + 1) * vspacing
                    if blackkeys.contains(i)
                    {
                        height = height + keyheight * 0.1
                    }
                    
                    keybuttons[j*12 + i].frame = CGRect(x: CGFloat(i) * spacing + keyoffset, y: 3.2*vspacing - height, width: keywidth, height: keyheight)
                    
                    keybuttons[j*12 + i].fontSize = min(14, keyheight * 0.5)
                }
            }
            
            CATransaction.commit()
        }
    }
    
    override func tintColorDidChange() {
        for k in keybuttons {
            k.tintColor = self.tintColor.cgColor
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.awakeFromNib()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    // MARK: Touch Event Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let pointOfTouch = touches.first?.location(in: self)
        
        delegate?.harmonizerView(self, touchIsDown: true)
        
        let key = containerLayer.hitTest(pointOfTouch!) as? GlowButton
        if (key != nil)
        {
            self.setSelectedKeycenter(Float(key!.keycenter))
            delegate?.harmonizerView(self, didChangeKeycenter: Float(key!.keycenter))
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        let p = touches.first?.location(in: self)
        let old_p = touches.first?.previousLocation(in: self)
        let key = containerLayer.hitTest(p!) as? GlowButton
        let old_key = containerLayer.hitTest(old_p!) as? GlowButton
        
        if (key != nil && key != old_key)
        {
            self.setSelectedKeycenter(Float(key!.keycenter))
            delegate?.harmonizerView(self, didChangeKeycenter: Float(key!.keycenter))
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        delegate?.harmonizerView(self, touchIsDown: false)
    }
}
