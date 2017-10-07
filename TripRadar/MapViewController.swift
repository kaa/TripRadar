//
//  ViewController.swift
//  TripRadar
//
//  Created by Joakim Beijar on 12/02/16.
//  Copyright © 2016 monografi. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class MapViewController: UIViewController, MKMapViewDelegate {
    var segments : [RouteSegment] = []
    var polyline : MKPolyline = MKPolyline()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Start waypoint
        var wp = WaypointAnnotation()
        wp.isStart = true
        wp.coordinate = segments[0].start
        wp.title = segments[0].name
        mapView.addAnnotation(wp)
        
        // End waypoint
        wp = WaypointAnnotation()
        wp.isStart = false
        wp.coordinate = segments[segments.count-1].end
        wp.title = segments[segments.count-1].name
        mapView.addAnnotation(wp)
        
        // Route
        var coordinates = segments.map { t in t.start }
        coordinates.append(segments[segments.count-1].end)
        polyline = MKPolyline(coordinates: &coordinates, count: coordinates.count)
        self.mapView.add(polyline)
        
        // Cameras
        let cameraAnnotations = segments
            .filter { $0.camera != nil && $0.camera!.isActive }
            .map {t in t.camera!}
            .map {t -> MKPointAnnotation in
                let annotation = CameraAnnotation()
                annotation.coordinate = t.coordinates
                annotation.title = t.name
                annotation.isActive = t.isActive
                return annotation
            }
        mapView.addAnnotations(cameraAnnotations)
        
        // Focus map on route
        mapView.setVisibleMapRect(
            polyline.boundingMapRect,
            edgePadding: UIEdgeInsetsMake(50,50,50,50),
            animated: true
        )
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBOutlet weak var mapView: MKMapView!

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if let cameraAnnotation = annotation as? CameraAnnotation {
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: "camera")
            if view == nil {
                view = MKAnnotationView(annotation: cameraAnnotation, reuseIdentifier: "camera")
            }
            view!.image = UIImage(named: "white")
            view!.canShowCallout = true
            return view
        }
        if let waypointAnnotation = annotation as? WaypointAnnotation {
            var view = mapView.dequeueReusableAnnotationView(withIdentifier: "waypoint")
            if view == nil {
                view = MKAnnotationView(annotation: waypointAnnotation, reuseIdentifier: "waypoint")
            }
            let image = UIImage(named: waypointAnnotation.isStart ? "start" : "goal")!
            view!.image = image
            view!.canShowCallout = true
            return view
        }
        return nil
    }
    
    var renderer : MKPolylineRenderer?
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let overlay = overlay as? MKPolyline {
            if renderer===nil {
                let renderer = MKPolylineRenderer(polyline: overlay)
                renderer.lineWidth = 3.0
                renderer.strokeColor = UIColor(red: 0, green: 90/255.0, blue: 1, alpha: 0.75)
                self.renderer = renderer
            }
            return self.renderer!
        }
        return MKOverlayRenderer()
    }
}

class CameraAnnotation : MKPointAnnotation {
    var isActive = false
}

class WaypointAnnotation : MKPointAnnotation {
    var isStart = false
}

