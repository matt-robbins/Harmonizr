//
//  FilesTableViewCell.swift
//  iOSHarmonizerApp
//
//  Created by Matthew E Robbins on 3/23/20.
//

import UIKit
import AVFoundation
import AVKit

class FilesTableViewCell: UITableViewCell, AVAudioPlayerDelegate {

    let playButton = UIButton(type:.system)
    let shareButton = UIButton(type:.system)
    let nameLabel = UILabel()
    let progressBar = UIProgressView()
    let volumeBar = UIProgressView()
    let stack = UIStackView()
    let vStack = UIStackView()
    var recordingURL:URL!
    var audioPlayer:AVAudioPlayer? = nil
    var parentController:UITableViewController? = nil
    var updater:CADisplayLink? = nil
    
    var file:String = "" {
        didSet {
            nameLabel.text = file
        }
    }
    func setButtonIcon(_ button: UIButton, named: String)
    {
        if #available(iOSApplicationExtension 18.0, *) {
            button.setImage(UIImage(named:named), for: .normal)
            return
        }
        let im = UIImage(named: named)?.withRenderingMode(.alwaysTemplate)
        let inset = button.frame.height/5
        button.setImage(im, for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.imageEdgeInsets = UIEdgeInsetsMake(inset, inset, inset, inset)
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
//        self.contentView.backgroundColor = UIColor.black
//        self.contentView.isOpaque = true
            
        self.selectionStyle = .none
        
        stack.axis = .horizontal
        stack.spacing = 10
        
        let viewsDict = [
            "stack": stack,
        ]
        
        for v in viewsDict.values {
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
        }
        playButton.isUserInteractionEnabled = true
        playButton.adjustsImageWhenHighlighted = true
        shareButton.adjustsImageWhenHighlighted = true
        
        setButtonIcon(playButton, named:"play.fill")
        setButtonIcon(shareButton, named:"square.and.arrow.up")

        
//        if #available(iOS 13.0, *) {
//            playButton.setImage(UIImage(systemName: "play.fill"), for: .normal)
//        } else {
//            playButton.setTitle("play", for: .normal)
//        }
//        if #available(iOS 13.0, *) {
//            shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
//        } else {
//            shareButton.setTitle("share", for: .normal)
//        }
        
        playButton.addTarget(self, action: #selector(self.play(_:)), for: .touchDown)
        shareButton.addTarget(self, action: #selector(self.share(_:)), for: .touchDown)
        
        stack.addArrangedSubview(nameLabel)
        stack.addArrangedSubview(UIView())
        stack.addArrangedSubview(playButton)
        stack.addArrangedSubview(vStack)
        stack.addArrangedSubview(shareButton)
        
        vStack.axis = .vertical
        vStack.distribution = .fill
        vStack.spacing = 0
        vStack.addArrangedSubview(UIView())
        vStack.addArrangedSubview(progressBar)
        vStack.addArrangedSubview(volumeBar)
        vStack.addArrangedSubview(UIView())
        
//        contentView.addConstraints(NSLayoutConstraint.constraints(
//            withVisualFormat: "V:|-[name]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
//        contentView.addConstraints(NSLayoutConstraint.constraints(
//        withVisualFormat: "V:|-[play]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
//        contentView.addConstraints(NSLayoutConstraint.constraints(
//        withVisualFormat: "V:|-[share]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
        contentView.addConstraints(NSLayoutConstraint.constraints(
        withVisualFormat: "V:|-[stack]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
        contentView.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-[stack]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
        progressBar.heightAnchor.constraint(equalToConstant: 5).isActive = true
        vStack.widthAnchor.constraint(equalTo: stack.widthAnchor, multiplier: 0.5).isActive = true
//        contentView.addConstraints(NSLayoutConstraint.constraints(
//            withVisualFormat: "H:[play]-[prog]-[share]-|", options: [], metrics: nil, views: viewsDict as [String : Any]))
        
        updater = CADisplayLink(target: self, selector: #selector(updateUI))
        updater?.add(to: .current, forMode: .defaultRunLoopMode)
        updater?.isPaused = true
    }

//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//        print("selected")
//        // Configure the view for the selected state
//    }
    
    @objc func updateUI()
    {
        let prog = (audioPlayer?.currentTime ?? 0.0) / (audioPlayer?.duration ?? 1.0)
        audioPlayer?.updateMeters()
        let pwr = ((audioPlayer?.averagePower(forChannel: 0) ?? -160.0) + 80.0) / 80.0
        
        progressBar.setProgress(Float(prog), animated: true)
        volumeBar.setProgress(pwr, animated: false)
        volumeBar.tintColor = pwr > 0.9 ? .red : .green
    }
    
    @objc func play(_ sender: UIButton) {
        if (audioPlayer?.isPlaying ?? false)
        {
            audioPlayer?.stop()
            audioPlayerDidFinishPlaying(audioPlayer!, successfully: true)
            progressBar.setProgress(0.0, animated: false)
            volumeBar.setProgress(0.0, animated: false)
            updater?.isPaused = true
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recordingURL.appendingPathComponent(file))
            audioPlayer?.delegate = self
        }
        catch {
            print(error.localizedDescription)
        }
        audioPlayer?.isMeteringEnabled = true
        audioPlayer?.play()
        updater?.isPaused = false
        
        UIView.transition(with: playButton, duration: 0.2, options: .transitionFlipFromRight, animations: {
            //self.playButton.setImage(UIImage(systemName: "stop.fill"), for: .normal)
            self.setButtonIcon(self.playButton, named: "stop.fill")
        }, completion: nil)
    }
    @objc func share(_ sender: UIButton) {
        print("presenting")
        let activityVC = UIActivityViewController(activityItems: [recordingURL.appendingPathComponent(file)],applicationActivities: nil)
        activityVC.popoverPresentationController?.sourceView = self
  
        parentController?.present(activityVC, animated: true, completion: nil)
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully: Bool)
    {
        print("finished!")
        UIView.transition(with: playButton, duration: 0.2, options: .transitionFlipFromLeft, animations: {
            self.setButtonIcon(self.playButton,named:"play.fill")
        }, completion: nil)
    }

}
