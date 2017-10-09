//
//  RouteViewController.swift
//  TripRadar
//
//  Created by Joakim Beijar on 16/02/16.
//  Copyright © 2016 monografi. All rights reserved.
//

import UIKit
import MapKit
import SDWebImage

struct CameraSegment {
    let name: String
    let weatherReport: WeatherReport?
    let distance : Double
    let cameras : [Camera]
}

class RouteViewController: UITableViewController {
    
    @IBOutlet weak var endDistanceLabel: DistanceLabel!
    @IBOutlet weak var startLabel: UILabel!
    @IBOutlet weak var endLabel: UILabel!

    var segments : [RouteSegment] = [] {
        didSet {
            var distance = 0.0
            cameraSegments.removeAll()
            cameraSegmentHeights.removeAll()
            print("nowhas",segments.count)
            for segment in segments {
                distance = distance + segment.distance
                guard let station = segment.station else {
                    continue;
                }
                //if !camera.isActive { continue }
                cameraSegments.append(CameraSegment(name: station.name, weatherReport: station.weatherReport, distance: distance, cameras: station.cameras))
                cameraSegmentHeights.append(-1.0)
                distance = 0.0
            }
            print("nowdisplaying",cameraSegments.count)
        }
    }
    
    var cameraSegments : [CameraSegment] = []
    var cameraSegmentHeights : [CGFloat] = []
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cameraSegments.count
    }
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cameraCell") as! CameraTableViewCell
        return cell
    }
    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let cameraCell = cell as! CameraTableViewCell
        cameraCell.item = cameraSegments[indexPath.item]
    }
    
    var _prototypeCell : CameraTableViewCell?
    var prototypeCell : CameraTableViewCell {
        get {
            if _prototypeCell==nil {
                _prototypeCell = tableView.dequeueReusableCell(withIdentifier: "cameraCell") as? CameraTableViewCell
            }
            return _prototypeCell!
        }
    }
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView.frame.width * CGFloat(576.0/704.0) + 96
    }
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var cachedHeight = cameraSegmentHeights[indexPath.item]
        if(cachedHeight<0) {
            prototypeCell.item = cameraSegments[indexPath.item]
            prototypeCell.layoutIfNeeded()
            var fit = UILayoutFittingCompressedSize
            fit.width = tableView.frame.width
            let size = prototypeCell.systemLayoutSizeFitting(fit, withHorizontalFittingPriority: UILayoutPriority(rawValue: 1000), verticalFittingPriority: UILayoutPriority(rawValue: 250))
            cameraSegmentHeights[indexPath.item] = size.height
            cachedHeight = size.height
        }
        return cachedHeight
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        startLabel.text = segments[0].name
        endLabel.text = segments[segments.count-1].name
        endDistanceLabel.distance = segments[segments.count-1].distance
        tableView.register(UINib(nibName: "CameraTableViewCell", bundle: nil), forCellReuseIdentifier: "cameraCell")
        SDImageCache.shared().clearMemory()
        SDImageCache.shared().clearDisk {}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toMap",
            let mapController = segue.destination as? MapViewController {
            mapController.segments = segments
        }
    }
}
