//
//  Extensions.swift
//  TripRadar
//
//  Created by Joakim Beijar on 15/02/16.
//  Copyright © 2016 monografi. All rights reserved.
//

import Foundation
import CoreLocation
import UIKit

extension CGPoint {
    func distanceToSegment(a : CGPoint, b : CGPoint) -> Double {
        var x = a.x,
        y = a.y,
        t : CGFloat,
        dx = b.x - x,
        dy = b.y - y
        let dot = dx * dx + dy * dy
        
        if (dot > 0) {
            t = ((self.x - x) * dx + (self.y - y) * dy) / dot;
            
            if (t > 1) {
                x = b.x;
                y = b.y;
            } else if (t > 0) {
                x += dx * t;
                y += dy * t;
            }
        }
        
        dx = self.x - x;
        dy = self.y - y;
        
        return sqrt(Double(dx * dx + dy * dy));
    }
}
extension CLLocationCoordinate2D {
    
    func projectToPoint() -> CGPoint {
        let R : Double = 6378137
        let MAX_LATITUDE : Double = 85.0511287798
        let d = Double.pi / 180,
        max = MAX_LATITUDE,
        p_lat = fmax(fmin(max, self.latitude), -max),
        p_sin = -sin(p_lat * d);
        return CGPoint(
            x: R * self.longitude * d,
            y: R * log((1 + p_sin) / (1 - p_sin)) / 2
        )
    }
    
    func distanceToSegment(start: CLLocationCoordinate2D, end: CLLocationCoordinate2D) -> Double {
        let radius = Double(6371e3);
        let δ13 = start.distanceFrom(destination: self)/radius
        let θ13 = start.bearingTo(destination: self)
        let θ12 = start.bearingTo(destination: end)
        let dxt = asin( sin(δ13) * sin(θ13-θ12) ) * radius;
        return dxt;
    }
    
    func distanceFrom(destination:CLLocationCoordinate2D) -> Double {
        let selfLocation = CLLocation(latitude: self.longitude, longitude: self.latitude)
        let destLocation = CLLocation(latitude: destination.longitude, longitude: destination.latitude)
        return Double(selfLocation.distance(from: destLocation))
    }
    
    func bearingTo(destination:CLLocationCoordinate2D) -> Double {
        let lat1 = self.latitude * .pi / 180
        let lon1 = self.longitude * .pi / 180
        let lat2 = destination.latitude * .pi / 180
        let lon2 = destination.longitude * .pi / 180
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return atan2(y, x)
    }
}
