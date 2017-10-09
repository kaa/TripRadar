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

class Camera : Codable {
    var id: String = ""
    var name: String = ""
    var lat: Double = 0
    var lng: Double = 0
    var roadNr: Int = 0
    var weatherStationId: String = ""
    var directions: [CameraDirection] = []
    var weatherReport : WeatherPreset?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case lat
        case lng
        case roadNr
        case weatherStationId
        case directions
        case weatherReport
    }
    
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self);
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .id)
        let latStr = try values.decode(String.self, forKey: .lat)
        lat = Double(latStr)!
        let lngStr = try values.decode(String.self, forKey: .lng)
        lng = Double(lngStr)!
        let roadNrStr = try values.decode(String.self, forKey: .roadNr)
        roadNr = Int(roadNrStr)!
        weatherStationId = try values.decode(String.self, forKey: .weatherStationId)
        directions = try values.decode([CameraDirection].self, forKey: .directions)
        weatherReport = try values.decodeIfPresent(WeatherPreset.self, forKey: .weatherReport)
    }

    private var _coordinates : CLLocationCoordinate2D? = nil
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

    private var _projectedPoint : CGPoint? = nil
    var projectedPoint : CGPoint {
        get {
            if(_projectedPoint==nil) {
                _projectedPoint = coordinates.projectToPoint()
            }
            return _projectedPoint!
        }
    }
}

class CameraDirection : Codable {
    var id : String = ""
    var direction : String = ""
    var latestImageDate : Date?
    var isPublic : Bool = false
    var isActive : Bool {
        get {
            return latestImageDate != nil && Date().timeIntervalSince(latestImageDate!) < 60*60*45 // 30 minutes ago
        }
    }
    private enum CodingKeys: String, CodingKey {
        case id
        case direction
        case latestImageDate
        case isPublic
    }
    public required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self);
        id = try values.decode(String.self, forKey: .id)
        direction = try values.decode(String.self, forKey: .direction)
        latestImageDate = try values.decodeIfPresent(Date.self, forKey: .latestImageDate)
        isPublic = try values.decodeIfPresent(Bool.self, forKey: .isPublic ) ?? false
    }
}
