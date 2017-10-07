//
//  CameraTableViewCell.swift
//  TripRadar
//
//  Created by Joakim Beijar on 16/02/16.
//  Copyright © 2016 monografi. All rights reserved.
//

import UIKit
import SDWebImage

class CameraTableViewCell: UITableViewCell, UIScrollViewDelegate {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var cardView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var pageControl: UIPageControl!
    @IBOutlet weak var distanceLabel: DistanceLabel!
    @IBOutlet weak var weatherLabel: UILabel!
    
    var item : CameraSegment? {
        didSet {
            guard let item = self.item else { return }
            nameLabel.text = item.camera.name
            for view in stackView.subviews {
                view.removeFromSuperview()
            }
            for con in scrollView.constraints {
                if let _ = con.secondItem as? UIImageView {
                    scrollView.removeConstraint(con)
                }
            }
            let positiveTemperatureColor = UIColor.black
            let negativeTemperatureColor = UIColor(red: 0, green: 90/255.0, blue: 1, alpha: 1)
            distanceLabel.distance = item.distance
            let weatherString = NSMutableAttributedString()
            if let roadTemperature = item.camera.weatherReport?.roadTemperature {
                weatherString.append(NSAttributedString(string: "Road "))
                weatherString.append(NSAttributedString(string: "\(roadTemperature)°", attributes: [
                    NSAttributedStringKey.foregroundColor: roadTemperature >= 0 ? positiveTemperatureColor : negativeTemperatureColor
                ]))
                weatherString.append(NSAttributedString(string: " "))
            }
            if let airTemperature = item.camera.weatherReport?.airTemperature {
                weatherString.append(NSAttributedString(string: "Air "))
                weatherString.append(NSAttributedString(string: "\(airTemperature)°", attributes: [
                    NSAttributedStringKey.foregroundColor: airTemperature >= 0 ? positiveTemperatureColor : negativeTemperatureColor
                ]))
            }
            weatherLabel.attributedText = weatherString
            
            let activeDirections = item.camera.directions.filter { $0.isActive }
            if activeDirections.count == 0 {
                let imageView = UIImageView()
                imageView.image = UIImage(named: "default")
                stackView.addArrangedSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.addConstraint(
                    NSLayoutConstraint(
                        item: imageView,
                        attribute: NSLayoutAttribute.height,
                        relatedBy: NSLayoutRelation.equal,
                        toItem: imageView,
                        attribute: NSLayoutAttribute.width,
                        multiplier: 576/704.0,
                        constant: 0.0
                    )
                )
                scrollView.addConstraint(
                    NSLayoutConstraint(
                        item: scrollView,
                        attribute: NSLayoutAttribute.width,
                        relatedBy: NSLayoutRelation.equal,
                        toItem: imageView,
                        attribute: NSLayoutAttribute.width,
                        multiplier: 1.0,
                        constant: 0.0
                    )
                )
            } else {
            for direction in activeDirections {
                let cameraUrl = "http://weathercam.digitraffic.fi/\(direction.id).jpg"
                let imageView = UIImageView()
                stackView.addArrangedSubview(imageView)
                imageView.translatesAutoresizingMaskIntoConstraints = false
                imageView.alpha = 0
                imageView.sd_setImage(
                    with: URL(string: cameraUrl)!,
                    placeholderImage: UIImage(named: "default"),
                    options: SDWebImageOptions.retryFailed
                ) {
                    image, error, cacheType, imageUrl in
                    if cacheType != SDImageCacheType.none {
                        imageView.alpha = 1
                    } else {
                        UIView.animate(withDuration: 0.25) { imageView.alpha = 1 }
                    }
                }
                imageView.addConstraint(
                    NSLayoutConstraint(
                        item: imageView,
                        attribute: NSLayoutAttribute.height,
                        relatedBy: NSLayoutRelation.equal,
                        toItem: imageView,
                        attribute: NSLayoutAttribute.width,
                        multiplier: 576/704.0,
                        constant: 0.0
                    )
                )
                scrollView.addConstraint(
                    NSLayoutConstraint(
                        item: scrollView,
                        attribute: NSLayoutAttribute.width,
                        relatedBy: NSLayoutRelation.equal,
                        toItem: imageView,
                        attribute: NSLayoutAttribute.width,
                        multiplier: 1.0,
                        constant: 0.0
                    )
                )
            }
            }
            scrollView.isScrollEnabled = stackView.arrangedSubviews.count > 1
            pageControl.numberOfPages = stackView.arrangedSubviews.count
        }
    }
        
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        pageControl.addTarget(self, action: Selector(("changePage:")), for: UIControlEvents.valueChanged)
        scrollView.delegate = self
        
    }
    func changePage(sender: AnyObject) -> () {
        let x = CGFloat(pageControl.currentPage) * scrollView.frame.size.width
        scrollView.setContentOffset(CGPoint(x: x, y: 0), animated: true)
    }
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) -> () {
        let pageNumber = round(scrollView.contentOffset.x / scrollView.frame.size.width);
        pageControl.currentPage = Int(pageNumber)
    }
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
}
