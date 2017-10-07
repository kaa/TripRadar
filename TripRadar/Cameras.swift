//
//  Cameras.swift
//  TripRadar
//
//  Created by Joakim Beijar on 16/02/16.
//  Copyright © 2016 monografi. All rights reserved.
//

import Foundation
import CoreLocation
import CoreGraphics

class Camera : NSObject {
    var id: String = ""
    var name: String = ""
    var lat: Double = 0
    var lng: Double = 0
    var roadNr: Int = 0
    var weatherStationId: String = ""
    var directions: [CameraDirection] = []
    var weatherReport : WeatherPreset?
    
    private var _coordinates : CLLocationCoordinate2D?
    var coordinates : CLLocationCoordinate2D {
        get {
            if(_coordinates==nil) {
                _coordinates = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            }
            return _coordinates!
        }
    }
    
    var isActive : Bool {
        get { return directions.filter { $0.isActive }.count > 0 }
    }

    private var _projectedPoint : CGPoint?
    var projectedPoint : CGPoint {
        get {
            if(_projectedPoint==nil) {
                _projectedPoint = coordinates.projectToPoint()
            }
            return _projectedPoint!
        }
    }
}

class CameraDirection : NSObject {
    var id : String = ""
    var direction : String = ""
    var latestImageDate : Date?
    var isPublic : Bool = false
    var isActive : Bool {
        get {
            return latestImageDate != nil && Date().timeIntervalSince(latestImageDate!) < 60*60*45 // 30 minutes ago
        }
    }
}
