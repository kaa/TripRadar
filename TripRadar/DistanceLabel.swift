//
//  DistanceLabel.swift
//  TripRadar
//
//  Created by Joakim Beijar on 01/03/16.
//  Copyright © 2016 monografi. All rights reserved.
//

import UIKit

class DistanceLabel: UILabel {
    var distance : Double = 0.0 {
        didSet {
            if distance>1000 {
                text = "\(Int(round(distance/1000))) km"
            } else {
                text = "\(Int(round(distance))) m"
            }
        }
    }
}
