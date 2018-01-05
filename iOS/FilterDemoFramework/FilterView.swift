/*
	Copyright (C) 2016 Apple Inc. All Rights Reserved.
	See LICENSE.txt for this sample’s licensing information
	
	Abstract:
	View for the FilterDemo audio unit. This lets the user adjust the filter cutoff frequency and resonance on an X-Y grid.
*/

import UIKit

/* 
    The `FilterViewDelegate` protocol is used to notify a delegate (`FilterDemoViewController`)
    when the user has changed the frequency or resonance by tapping and dragging 
    in the graph.

    `filterViewDataDidChange(_:)` is called when the view size changes and new 
    frequency data is available.
 */
protocol FilterViewDelegate: class {
    func filterView(_ filterView: FilterView, didChangeKeycenter keycenter: Float)
    func filterView(_ filterView: FilterView, didChangeInversion inversion: Float)
    func filterView(_ filterView: FilterView, didChangeNvoices voices: Float)
    func filterView(_ filterView: FilterView, didChangeTriad triad: Float)
    func filterView(_ filterView: FilterView, didChangeEnable enable: Float)
    func filterView(_ filterView: FilterView, didChangeMidi midi: Float)
    func filterView(_ filterView: FilterView, didChangeBypass bypass: Float)
    func filterView(_ filterView: FilterView, didChangePreset preset: Int)
    func filterViewGetPitch(_ filterView: FilterView) -> Float
    func filterViewGetKeycenter(_ filterView: FilterView) -> Float
    func filterViewDataDidChange(_ filterView: FilterView)
    func filterViewConfigure(_ filterView: FilterView)
    func filterViewSavePreset(_ filterView: FilterView)
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

class FilterView: UIView {
    // MARK: Properties

    var enable = 1
    var midi_enable = 1
    var inversion: Int = 2 {
        didSet(old_inversion) {
            //setSelectedInversion(Float(inversion))
            //print("someone set inversion to \(inversion) from \(old_inversion)")
        }
    }
    var keycenter = 0
    
    var bypass: Int = 0 {
        didSet(old_bypass) {
            setBypassEnable(Float(bypass))
            //print("someone set inversion to \(inversion) from \(old_inversion)")
        }
    }
    
    var presets = [AUAudioUnitPreset]() {
        didSet(old_presets) {
            print(presets as Any)
        }
    }
    
    var preset: AUAudioUnitPreset? = nil {
        didSet(old_preset) {
            presetbutton.string = preset!.name
        }
    }
    
    let triads = [6,15,17]
    var lastNote = -1
    var triad_override = false
    
    var keybuttons = [VerticallyCenteredTextLayer]()
    var triadbuttons = [CALayer]()
    var invbuttons = [CALayer]()
    var fcnbuttons = [CALayer]()
    var configbutton = VerticallyCenteredTextLayer()
    var midibutton = VerticallyCenteredTextLayer()
    var presetbutton = VerticallyCenteredTextLayer()
    var midiautobutton = CALayer()
    var containerLayer = CALayer()
    var nvoicesLayer = CALayer()
    var keysLayer = CALayer()
    var graphLayer = CALayer()
    var curveLayer: CAShapeLayer?
    
    var pulseAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
    var glowAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.shadowOpacity))
    var redAnimation = CABasicAnimation(keyPath: #keyPath(CALayer.backgroundColor))
    
    // The delegate to notify of paramater and size changes.
    weak var delegate: FilterViewDelegate?

    var editPoint = CGPoint.zero
    var touchDown = false
    var currentKey = 0
    var currentTriad = -1
    
    func highlight(layer: CALayer?)
    {
        layer!.borderColor = UIColor.cyan.cgColor
        layer!.shadowOpacity = 1.0
    }
    func dehighlight(layer: CALayer?)
    {
        layer!.borderColor = UIColor.darkGray.cgColor
        layer!.shadowOpacity = 0.0
    }
    
    func setSelectedNote(_ note: Float) {
        let n = keybuttons.count
        
        let curr_note = Int(round(note))

        if (curr_note == lastNote)
        {
            return
        }
        for j in 0...n-1 {
            if (j % 12 == curr_note)
            {
                CATransaction.begin()
                CATransaction.setAnimationDuration(0.05)
                keybuttons[j].shadowColor = UIColor.red.cgColor
                keybuttons[j].shadowOpacity = 1.0
                CATransaction.commit()
            }
            else
            {
                CATransaction.begin()
                CATransaction.setAnimationDuration(1.0)
                keybuttons[j].shadowOpacity = 0.0
                keybuttons[j].shadowColor = UIColor.cyan.cgColor
                CATransaction.commit()
            }
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
            if (keybuttons[key].borderColor != UIColor.darkGray.cgColor)
            {
                keybuttons[key].removeAnimation(forKey: "pulse")
                keybuttons[key].borderColor = UIColor.darkGray.cgColor
                keybuttons[key].shadowOpacity = 0.0
            }
        }
        
        keybuttons[new_key].add(pulseAnimation, forKey:"pulse")
        keybuttons[new_key].shadowOpacity = 1.0
        keybuttons[new_key].borderColor = UIColor.cyan.cgColor
        
        currentKey = new_key
    }
    
    func setSelectedInversion(_ inversion: Float)
    {
        for k in 0...2
        {
            let sublayers = invbuttons[k].sublayers!
            
            if (Int(inversion) == k)
            {
                highlight(layer: invbuttons[k])
                //                        invbuttons[k].shadowOpacity = 1.0
                //                        invbuttons[k].borderColor = UIColor.cyan.cgColor
                
                for l in 0...sublayers.count - 1
                {
                    if (l != k)
                    {
                        sublayers[l].borderColor = UIColor.cyan.cgColor
                        sublayers[l].shadowOpacity = 0.5
                    }
                }
            }
            else
            {
                dehighlight(layer: invbuttons[k])
                //                        invbuttons[k].shadowOpacity = 0.0
                //                        invbuttons[k].borderColor = UIColor.darkGray.cgColor
                
                for l in 0...sublayers.count - 1
                {
                    if (l != k)
                    {
                        sublayers[l].borderColor = UIColor.lightGray.cgColor
                        sublayers[l].shadowOpacity = 0
                    }
                }
            }
        }
    }
    
    func setSelectedVoices(_ voices: Int, inversion: Int)
    {
        let sublayers = nvoicesLayer.sublayers!
        
        var sum = 0
        for k in 0...voices
        {
            sum += k
        }
        
        for k in 0...sublayers.count - 1
        {
            if (k < sum && k >= (sum - voices))
            {
                if ((k - (sum - voices)) > inversion)
                {
                    sublayers[k].borderColor = UIColor.cyan.cgColor
                    sublayers[k].shadowOpacity = 1.0
                }
                else
                {
                    sublayers[k].borderColor = UIColor.yellow.cgColor
                    sublayers[k].shadowOpacity = 1.0
                }
            }
            else
            {
                sublayers[k].borderColor = UIColor.lightGray.cgColor
                sublayers[k].shadowOpacity = 0.0
            }
        }
    }
    
    func setBypassEnable(_ enable: Float)
    {
        if Int(enable) == 1
        {
            highlight(layer: configbutton)
        }
        else
        {
            dehighlight(layer: configbutton)
        }
    }

    override func awakeFromNib() {
        // Create all of the CALayers for the graph, lines, and labels.
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
        
        keysLayer.name = "keys"
        keysLayer.frame = CGRect(
            x: 0, y: containerLayer.frame.height - 3.2 * containerLayer.frame.height/12, width: containerLayer.frame.width, height: 3.2 * containerLayer.frame.height/12)
        keysLayer.opacity = 1.0
        containerLayer.addSublayer(keysLayer)
        
        let keywidth = containerLayer.frame.width / 12
        
        for j in 0...2
        {
            let names = ["C", "C\u{266f}", "D", "D\u{266f}", "E", "F", "F\u{266f}",
                         "G", "A\u{266D}", "A", "B\u{266D}", "B"]
            
            for i in 0...11
            {
                let keyLayer = VerticallyCenteredTextLayer()
                keyLayer.contentsScale = UIScreen.main.scale
                let blackkeys = [1,3,6,8,10]
                
                if (j == 0)
                {
                    keyLayer.string = names[i]
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
                
                var bri = 0.9

                if blackkeys.contains(i) {
                    bri = 0.1
                }
                
                keyLayer.backgroundColor = UIColor(hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(bri), alpha: 1.0).cgColor
                
                keyLayer.foregroundColor = UIColor(hue: CGFloat(0), saturation: CGFloat(0), brightness: CGFloat(1-bri), alpha: 1.0).cgColor
                
                keyLayer.borderColor = UIColor.darkGray.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
                keyLayer.borderWidth = 4
                keyLayer.cornerRadius = 4
                keyLayer.shadowColor = UIColor.cyan.cgColor
                keyLayer.shadowRadius = 8
                keyLayer.shadowOpacity = 0
                keyLayer.shadowOffset = CGSize(width: 0, height: 0)
                
                let xpos = CGFloat(i) * containerLayer.frame.width / 12
                
                keyLayer.frame = CGRect(x: xpos, y: CGFloat(j) * keywidth, width: keywidth, height: keywidth)
                keybuttons.append(keyLayer)

                keysLayer.addSublayer(keyLayer)
                
            }
        }
        
//        for j in 0...2
//        {
//            let invLayer = CALayer()
//
//            invLayer.borderColor = UIColor.darkGray.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
//            invLayer.backgroundColor = UIColor(white: 0.9, alpha: 1.0).cgColor
//            invLayer.borderWidth = 4
//            invLayer.cornerRadius = 4
//            invLayer.shadowRadius = 8
//            invLayer.shadowOpacity = 0
//            invLayer.shadowColor = UIColor.cyan.cgColor
//
//            let xpos = CGFloat(j + 1) * containerLayer.frame.width / 12
//
//            invLayer.frame = CGRect(x: xpos, y: containerLayer.frame.height - (CGFloat(j + 1) * keywidth), width: keywidth, height: keywidth)
//
//            if (j == 2)
//            {
//                invLayer.shadowOpacity = 1.0
//                invLayer.borderColor = UIColor.cyan.cgColor
//            }
//
//            invbuttons.append(invLayer)
//            containerLayer.addSublayer(invLayer)
//
//            for k in 0...2
//            {
//                let oval = CALayer()
//
//                oval.borderColor = UIColor.darkGray.cgColor
//                oval.borderWidth = 2
//                oval.cornerRadius = 2
//
//                oval.shadowColor = UIColor.cyan.cgColor
//                oval.shadowOpacity = 0.0
//                oval.shadowRadius = 2.0
//                oval.shadowOffset = CGSize(width: 0, height: 0)
//
//                if (k != j)
//                {
//                    oval.borderColor = UIColor.lightGray.cgColor
//                    oval.shadowOpacity = 0.0
//
//                    if (j == 2)
//                    {
//                        oval.borderColor = UIColor.cyan.cgColor
//                        oval.shadowOpacity = 0.5
//                    }
//                }
//
//                let xpos = invLayer.frame.width / 3
//                let ypos = invLayer.frame.height * CGFloat(k+2) / 4
//
//                //oval.frame = CGRect(x: xpos, y: ypos, width: invLayer.frame.width * CGFloat(5.0/6.0), height: 4)
//
//                invLayer.addSublayer(oval)
//            }
//        }
        
        for _ in 0...2
        {
            let triLayer = CALayer()
            triLayer.borderColor = UIColor.darkGray.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
            triLayer.backgroundColor = UIColor.yellow.cgColor
            triLayer.borderWidth = 4
            triLayer.cornerRadius = 4
            triLayer.shadowRadius = 8
            triLayer.shadowOpacity = 0
            triLayer.shadowColor = UIColor.yellow.cgColor
            triadbuttons.append(triLayer)
            containerLayer.addSublayer(triLayer)
        }
        
        configbutton.borderColor = UIColor.darkGray.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
        configbutton.backgroundColor = UIColor.white.cgColor
        configbutton.foregroundColor = UIColor.black.cgColor
        configbutton.borderWidth = 4
        configbutton.cornerRadius = 4
        configbutton.shadowRadius = 8
        configbutton.shadowColor = UIColor.cyan.cgColor
        configbutton.shadowOpacity = 0.0
        configbutton.contentsScale = UIScreen.main.scale
        configbutton.fontSize = 28
        configbutton.alignmentMode = kCAAlignmentCenter
        configbutton.string = "\u{2699}"

        configbutton.frame = CGRect(x: 0, y: containerLayer.frame.height - keywidth, width: keywidth, height: keywidth)
        containerLayer.addSublayer(configbutton)
        
        
        presetbutton.string = "Preset"
        presetbutton.fontSize = 14
        presetbutton.contentsScale = UIScreen.main.scale
        presetbutton.alignmentMode = kCAAlignmentCenter
        presetbutton.foregroundColor = UIColor.white.cgColor
        presetbutton.borderColor = UIColor.darkGray.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
        presetbutton.backgroundColor = UIColor.black.cgColor
        presetbutton.borderWidth = 4
        presetbutton.cornerRadius = 4
        presetbutton.shadowRadius = 8
        presetbutton.shadowColor = UIColor.cyan.cgColor
        presetbutton.shadowOpacity = 0.0
        containerLayer.addSublayer(presetbutton)
        
        //let midilogo = UIImage(named: "midi.png")?.cgImage
        midibutton.string = "MIDI"
        midibutton.fontSize = 14
        midibutton.contentsScale = UIScreen.main.scale
        midibutton.alignmentMode = kCAAlignmentCenter
        midibutton.foregroundColor = UIColor.black.cgColor
        midibutton.borderColor = UIColor.cyan.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
        midibutton.backgroundColor = UIColor.white.cgColor
        midibutton.borderWidth = 4
        midibutton.cornerRadius = 4
        midibutton.shadowRadius = 8
        midibutton.shadowColor = UIColor.cyan.cgColor
        midibutton.shadowOpacity = 1.0
        
        containerLayer.addSublayer(midibutton)
        

        nvoicesLayer.contentsScale = UIScreen.main.scale
        nvoicesLayer.borderColor = UIColor.darkGray.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
        nvoicesLayer.backgroundColor = UIColor.black.cgColor
        nvoicesLayer.borderWidth = 2
        nvoicesLayer.cornerRadius = 4
        nvoicesLayer.shadowRadius = 8
        nvoicesLayer.shadowColor = UIColor.cyan.cgColor
        nvoicesLayer.shadowOpacity = 0.0
        
        for k in 0...9
        {
            let oval = CALayer()
            
            oval.borderColor = UIColor.darkGray.cgColor
            oval.borderWidth = 4
            oval.cornerRadius = 4
            
            oval.shadowColor = UIColor.cyan.cgColor
            oval.shadowOpacity = 0.0
            oval.shadowRadius = 5.0
            oval.shadowOffset = CGSize(width: 0, height: 0)
            
            nvoicesLayer.addSublayer(oval)
        }
        
        containerLayer.addSublayer(nvoicesLayer)
        
        
        
//        midiautobutton.borderColor = UIColor.white.cgColor //UIColor(white: 1.0, alpha: 1.0).cgColor
//        midiautobutton.backgroundColor = UIColor.lightGray.cgColor
//        midiautobutton.borderWidth = 4
//        midiautobutton.cornerRadius = 4
//        midiautobutton.shadowRadius = 8
//        midiautobutton.shadowColor = UIColor.white.cgColor
//        midiautobutton.shadowOpacity = 1.0
//
//        containerLayer.addSublayer(midiautobutton)
        
        layer.contentsScale = scale
    }
    

    
	/*
		This function positions all of the layers of the view starting with 
		the horizontal dbLines and lables on the y axis. Next, it positions 
		the vertical frequency lines and labels on the x axis. Finally, it
		positions the controls and the curve layer.

		This method is also called when the orientation of the device changes
		and the view needs to re-layout for the new view size.
	 */
	override func layoutSublayers(of layer: CALayer) {        
        if layer === self.layer {
            // Disable implicit layer animations.
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            
            containerLayer.bounds = layer.bounds
            
            let keywidth = containerLayer.frame.width / 13
            let spacing = containerLayer.frame.width / 12
            
            keysLayer.frame = CGRect(
                x: 0, y: containerLayer.frame.height - keywidth * 4,
                width: containerLayer.frame.width,
                height: keywidth * 4)
            
            let blackkeys = [1,3,6,8,10]
            for j in 0...2 {
                for i in 0...11 {
                    var height = CGFloat(j + 1) * spacing
                    if blackkeys.contains(i)
                    {
                        height = height + keywidth * 0.25
                    }
                    
                    keybuttons[j*12 + i].frame = CGRect(x: CGFloat(i) * spacing + 4, y: keysLayer.frame.height - height, width: keywidth, height: keywidth)
                }
            }
            
//            for j in 0...2
//            {
//                invbuttons[j].frame = CGRect(x: CGFloat(j+1) * spacing + 4, y: keywidth / 4, width: keywidth, height: keywidth)
//
//                let sublayers = invbuttons[j].sublayers!
//                let pipheight = 4
//                for l in 0...sublayers.count - 1
//                {
//                    let xpos = invbuttons[j].frame.width / 4
//                    let ypos = invbuttons[j].frame.height * CGFloat(l+2) / 6 - CGFloat(pipheight) / 2
//
//                    sublayers[l].frame = CGRect(x: xpos, y: ypos, width: invbuttons[j].frame.width * CGFloat(1.0/2.0), height: CGFloat(pipheight))
//                }
//            }
            
            nvoicesLayer.frame = CGRect(x: 4 + spacing, y: keywidth / 4, width: 4 * spacing - 4, height: keywidth * 2)
            
            let sublayers = nvoicesLayer.sublayers!
            let pipheight = 8
            var count = 0
            let pad: CGFloat = 5
            for nv in 0...3
            {
                for p in 0...nv
                {
                    let xpos = pad + CGFloat(nv) * (nvoicesLayer.frame.width - 2*pad) / 4
                    let width: CGFloat = (nvoicesLayer.frame.width - 5 * pad) / 4
                    let ypos = nvoicesLayer.frame.height * (1 - (CGFloat(p) + 0.5) / 4) - CGFloat(pipheight) / 2
                    
                    sublayers[count].frame = CGRect(x: xpos, y: ypos, width: width, height: CGFloat(pipheight))
                    
                    count += 1
                }
            }
            
            for j in 0...2
            {
                triadbuttons[j].frame = CGRect(x: CGFloat(j+5) * spacing + 4, y: keywidth / 4, width: keywidth, height: keywidth)
            }
            
            configbutton.frame = CGRect(x: 4 + spacing * 11, y: keywidth / 4, width: keywidth, height: keywidth)
            midiautobutton.frame = CGRect(x: 4 + spacing * 10, y: keywidth / 4, width: keywidth, height: keywidth)
            
            presetbutton.frame = CGRect(x: 4 + spacing * 8, y: keywidth / 4, width: keywidth*3 + 4, height: keywidth/2)
            
            midibutton.frame = CGRect(x: 4, y: keywidth / 4, width: keywidth, height: keywidth)
            
            CATransaction.commit()
        }
        
        /*
            Notify view controller that our bounds has changed -- meaning that new
            frequency data is available.
        */
        //delegate?.filterViewDataDidChange(self)
    }

    /* 
        If either the frequency or resonance (or both) change, notify the delegate 
        as appropriate.
     */
    func updateFrequenciesAndResonance() {
       
    }
    
    func processVoicesTouch(point: CGPoint) {
        let hit = nvoicesLayer.hitTest(point)
        if (hit != nil)
        {
            let p = 1 + 4*((point.x - nvoicesLayer.frame.minX) / nvoicesLayer.frame.width)
            var inv = 4*(1 - ((point.y - nvoicesLayer.frame.minY) / nvoicesLayer.frame.height))
            if (inv > p - 1) { inv = p - 1 }
            print(inv)
            delegate?.filterView(self, didChangeNvoices: Float(p))
            delegate?.filterView(self, didChangeInversion: Float(inv))
            self.setSelectedVoices(Int(p), inversion: Int(inv))
            //self.setSelectedInversion(Float(inv))
        }
        
    }
    
    
    // MARK: Touch Event Handling
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        var pointOfTouch = touches.first?.location(in: self)
        
        pointOfTouch = CGPoint(x: pointOfTouch!.x, y: pointOfTouch!.y)
        
        processVoicesTouch(point: pointOfTouch!)
        
//        for j in 0...2
//        {
//            if (invbuttons[j].hitTest(pointOfTouch!) != nil)
//            {
//                if (inversion != j)
//                {
//                    delegate?.filterView(self, didChangeInversion: Float(j))
//                    delegate?.filterView(self, didChangeEnable: 1)
//                    inversion = j
//                }
//                else
//                {
//                    inversion = -1
//                    delegate?.filterView(self, didChangeEnable: 0)
//                }
//
//                self.setSelectedInversion(Float(inversion))
//            }
//        }
        
        for j in 0...triadbuttons.count-1
        {
            if (triadbuttons[j].hitTest(pointOfTouch!) != nil)
            {
                triadbuttons[j].borderColor = UIColor.white.cgColor
                triadbuttons[j].shadowOpacity = 1.0
                
                delegate?.filterView(self, didChangePreset: j)
//                delegate?.filterView(self, didChangeTriad: Float(triads[j]))
//                triad_override = true
            }
        }
        
        if (configbutton.hitTest(pointOfTouch!) != nil)
        {
            delegate?.filterViewConfigure(self)
//            bypass = bypass == 1 ? 0 : 1
//            delegate?.filterView(self, didChangeBypass: Float(bypass))
        }
        
        if (presetbutton.hitTest(pointOfTouch!) != nil)
        {
            delegate?.filterViewSavePreset(self)
        }
        
        if (midibutton.hitTest(pointOfTouch!) != nil)
        {
            if (midi_enable == 1)
            {
                delegate?.filterView(self, didChangeMidi: 0)
                midibutton.shadowOpacity = 0.0
                midibutton.borderColor = UIColor.darkGray.cgColor
                midi_enable = 0
            }
            else
            {
                delegate?.filterView(self, didChangeMidi: 1)
                midibutton.shadowOpacity = 1.0
                midibutton.borderColor = UIColor.cyan.cgColor
                midi_enable = 1
            }
        }
        
        pointOfTouch = CGPoint(x: pointOfTouch!.x, y: pointOfTouch!.y + keysLayer.frame.height - containerLayer.frame.height)
        
        for j in 0...35
        {
            if (keybuttons[j].hitTest(pointOfTouch!) != nil)
            {
                self.setSelectedKeycenter(Float(j))
                
                // change key center parameter based on x value of touch
                delegate?.filterView(self, didChangeKeycenter: Float(j))
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        var pointOfTouch = touches.first?.location(in: self)
        pointOfTouch = CGPoint(x: pointOfTouch!.x, y: pointOfTouch!.y)
        processVoicesTouch(point: pointOfTouch!)
        
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        //var pointOfTouch = touches.first?.location(in: self)
        
//        for key in 0...35
//        {
//            if (key == currentKey)
//            {
//            }
//            else
//            {
//                keybuttons[key].removeAnimation(forKey: "pulse")
//                keybuttons[key].borderColor = UIColor.darkGray.cgColor
//                keybuttons[key].shadowOpacity = 0.0
//            }
//        }
        
        for j in 0...triadbuttons.count-1
        {
            triadbuttons[j].shadowOpacity = 0.0
            triadbuttons[j].borderColor = UIColor.darkGray.cgColor
        }
        if (triad_override)
        {
            delegate?.filterView(self, didChangeTriad: Float(-1))
            triad_override = false
        }
        
        touchDown = false
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchDown = false
    }
    
    func processTouch(_ touchPoint: CGPoint) {
       
    }
}
