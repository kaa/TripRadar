//
//  RoutingService.swift
//  TripRadar
//
//  Created by Joakim Beijar on 15/02/16.
//  Copyright © 2016 monografi. All rights reserved.
//
import Foundation
import MapKit
import CoreLocation
import GoogleMaps
import GooglePlaces

var GlobalUserInitiatedQueue: DispatchQueue {
    return DispatchQueue.global(qos: .userInitiated)
}
var GlobalMainQueue: DispatchQueue {
    return DispatchQueue.main
}

class CameraPresetsParser : NSObject, XMLParserDelegate {
    var presets : [CameraPreset] = []
    var preset : CameraPreset = CameraPreset()
    var lastElementName = ""
    
    let dateFormatter = DateFormatter()
    override init() {
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        super.init()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName=="camerapreset" {
            preset = CameraPreset()
        } else {
            lastElementName = elementName
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName=="camerapreset" {
            presets.append(preset)
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        guard trimmedString.characters.count > 0 else { return }
        switch lastElementName {
        case "presetid":
            preset.id = preset.id+trimmedString
        case "public":
            preset.isPublic = trimmedString=="true"
        case "utc":
            if let date = dateFormatter.date(from: trimmedString) {
                preset.latestImageDate = date
            }
        default:
            break;
        }
    }
}

struct CameraPreset {
    var id : String = ""
    var isPublic : Bool = false
    var latestImageDate : Date?
}

class WeatherPresetsParser : NSObject, XMLParserDelegate {
    var presets : [String: WeatherPreset] = [String: WeatherPreset]()
    var preset : WeatherPreset = WeatherPreset()
    var lastElementName = ""
    
    let dateFormatter = DateFormatter()
    override init() {
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        super.init()
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String]) {
        if elementName=="roadweather" {
            preset = WeatherPreset()
        } else {
            lastElementName = elementName
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName=="roadweather" {
            presets[preset.id] = preset
        }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        let trimmedString = string.trimmingCharacters(in: NSCharacterSet.whitespacesAndNewlines)
        guard trimmedString.characters.count > 0 else { return }
        switch lastElementName {
        case "stationid":
            preset.id = preset.id+trimmedString
        case "airtemperature1":
            if let t = Double(trimmedString) {
                preset.airTemperature = t
            }
        case "airtemperature1change":
            if let t = Double(trimmedString) {
                preset.airTemperatureDelta = t
            }
        case "roadsurfacetemperature1":
            if let t = Double(trimmedString) {
                preset.roadTemperature = t
            }
        case "roadsurfacetemperature1change":
            if let t = Double(trimmedString) {
                preset.roadTemperatureDelta = t
            }
        case "averagewindspeed":
            if let t = Double(trimmedString) {
                preset.windDirection = t
            }
        case "winddirection":
            if let t = Double(trimmedString) {
                preset.windDirection = t
            }
        case "roadsurfaceconditions1":
            if let t = Int(trimmedString) {
                preset.roadConditions = t
            }
        case "warning1":
            if let t = Int(trimmedString) {
                preset.warningConditions = t
            }
        case "sunup":
            preset.sun = trimmedString=="1"
        case "bright":
            preset.bright = trimmedString=="1"
        case "utc":
            if let date = dateFormatter.date(from: trimmedString) {
                preset.latestReadingDate = date
            }
        default:
            break;
        }
    }
}

struct WeatherPreset {
    var id : String = ""
    var latestReadingDate : Date = Date(timeIntervalSince1970: 0)
    var airTemperature : Double = Double.signalingNaN
    var airTemperatureDelta : Double = Double.signalingNaN
    var roadTemperature : Double = Double.signalingNaN
    var roadTemperatureDelta : Double = Double.signalingNaN
    var windSpeed : Double = Double.signalingNaN
    var windDirection : Double = Double.signalingNaN
    var roadConditions : Int = 0
    var warningConditions : Int = 0
    var sun : Bool = false
    var bright : Bool = false
}

class RoutingService {
    func loadCameraPresets(completionHandler: @escaping ([CameraPreset],Error?) -> Void) {
        URLSession.shared.dataTask(with: URL(string:"http://tie.digitraffic.fi/sujuvuus/ws/cameraPresets")!) {
            maybeData, response, error in
            guard error == nil, let data = maybeData else { completionHandler([], error); return }
            let parser = XMLParser(data: data)
            let session = CameraPresetsParser()
            parser.delegate = session;
            parser.parse()
            DispatchQueue.main.async() {
                completionHandler(session.presets,parser.parserError)
            }
        }.resume()
    }
    
    func loadWeatherPresets(completionHandler: @escaping ([String: WeatherPreset],Error?) -> Void) {
        URLSession.shared.dataTask(with: URL(string:"http://tie.digitraffic.fi/sujuvuus/ws/roadWeather")!) {
            maybeData, response, error in
            guard error == nil, let data = maybeData else {
                completionHandler([String:WeatherPreset](), error)
                return
            }
            let parser = XMLParser(data: data)
            let session = WeatherPresetsParser()
            parser.delegate = session;
            parser.parse()
            DispatchQueue.main.async() {
                completionHandler(session.presets,parser.parserError)
            }
        }.resume()
    }
    
    func loadCameras(completionHandler: @escaping ([Camera], Error?) -> Void) {
        var cameras: [Camera] = []
        guard let filepath = Bundle.main.path(forResource: "cameras", ofType: "json") else {
            completionHandler(cameras, NSError(domain: "routing", code: 1, userInfo: nil))
            return
        }
        do {
            let c = jsonString.data()
            let contents = try NSString(contentsOfFile: filepath, usedEncoding: nil) as String
            cameras = [Camera](json: contents)
        } catch {
            completionHandler(cameras, NSError(domain: "routing", code: 2, userInfo: nil))
            return
        }
        
        let presetsGroup = DispatchGroup()

        var cameraError : Error?
        var maybeCameraPresets: [CameraPreset]?
        presetsGroup.enter()
        self.loadCameraPresets() {
            response, error in
            if error == nil {
                maybeCameraPresets = response
            } else {
                cameraError = error
            }
            presetsGroup.leave()
        }
        
        var weatherError : Error?
        var maybeWeatherPresets: [String:WeatherPreset]?
        presetsGroup.enter()
        self.loadWeatherPresets {
            response, error in
            if error == nil {
                maybeWeatherPresets = response
            } else {
                weatherError = error
            }
            presetsGroup.leave()
        }
  
        presetsGroup.notify(queue: GlobalMainQueue) {
            guard cameraError==nil else {
                completionHandler([],cameraError)
                return
            }
            guard weatherError==nil else {
                completionHandler([],weatherError)
                return
            }
            guard let cameraPresets = maybeCameraPresets,
                  let weatherPresets = maybeWeatherPresets else {
                completionHandler([],NSError(domain: "routing", code: 3, userInfo: nil))
                return
            }
            var directionsHash = [String: CameraDirection]()
            let t = cameras.map { $0.directions }.joined()
            for direction in t {
                directionsHash[direction.id] = direction
            }
            for preset in cameraPresets {
                if let direction = directionsHash[preset.id] {
                    direction.isPublic = preset.isPublic
                    direction.latestImageDate = preset.latestImageDate
                }
            }
            for camera in cameras {
                if let weatherPreset = weatherPresets[camera.weatherStationId] {
                    camera.weatherReport = weatherPreset
                }
            }
            completionHandler(cameras, nil)
        }
    }

    func describeRouteBetweenPoints(waypoints: [String], completionHandler: @escaping ([RouteSegment], NSError?) -> Void ) {
        findWaypoints(waypoints: waypoints) {
            responseWaypoints, error in
            guard error == nil else {
                completionHandler([], error)
                return
            }
            let foundWaypoints = responseWaypoints.filter { (t) in t !== nil }.map { $0! }
            guard foundWaypoints.count == responseWaypoints.count else {
                for i in 0...waypoints.count {
                    if responseWaypoints[i] != nil { continue }
                    print("Waypoint \(waypoints[i]) could not be found")
                }
                completionHandler([], nil)
                return
            }
            self.describeRouteBetweenPoints(foundWaypoints, completionHandler: completionHandler)
        }
    }

    func findWaypoints(waypoints: [String], completionHandler: @escaping ([MKPlacemark?], NSError?) -> Void) {
        var storedError: NSError!
        var results = [MKPlacemark?](repeating: nil, count: waypoints.count)
        let waypointGroup = DispatchGroup()
        DispatchQueue.apply(attributes: waypoints.count, iterations: GlobalUserInitiatedQueue) { i in
            let startQuery = MKLocalSearchRequest()
            startQuery.naturalLanguageQuery = waypoints[i];
            dispatch_group_enter(waypointGroup)
            MKLocalSearch(request: startQuery).startWithCompletionHandler { response, error in
                if error !== nil {
                    storedError = error
                } else if let item = response?.mapItems[0] {
                    results[i] = item.placemark
                }
                dispatch_group_leave(waypointGroup)
            }
        }
        waypointGroup.notify(queue: GlobalMainQueue) {
            completionHandler(results, storedError)
        }
    }

    func describeRouteBetweenPoints(waypoints: [MKPlacemark], completionHandler: @escaping ([RouteSegment], Error?) -> Void) {
        guard waypoints.count>0 else {
            completionHandler([], NSError(domain: "router", code: 1, userInfo: nil))
            return
        }
        if waypoints.count==1 {
            completionHandler([], nil)
            return
        }
        let directionsQuery = MKDirectionsRequest()
        directionsQuery.source = MKMapItem(placemark: waypoints[0])
        directionsQuery.destination = MKMapItem(placemark: waypoints[waypoints.count-1])
        MKDirections(request: directionsQuery).calculate {
            response, error in
            guard error == nil, let polyline = response?.routes[0].polyline else {
                completionHandler([], error);
                return
            }
            print(response!.routes.map { "\(response!.routes.count) \($0.name) \($0.distance) \($0.expectedTravelTime)" })
            var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
            polyline.getCoordinates(&coordinates, range: NSMakeRange(0, polyline.pointCount))
            self.describeRoute(routeCoordinates: coordinates) {
                response, error in
                guard error == nil else {
                    completionHandler([], error)
                    return
                }
                completionHandler(response, nil)
                return;
            }
        }
    }
    
    func describeRouteBetweenPoints(waypoints: [GMSPlace], completionHandler: @escaping ([RouteSegment], Error?) -> Void) {
        guard waypoints.count>0 else {
            completionHandler([], NSError(domain: "router", code: 1, userInfo: nil))
            return
        }
        if waypoints.count==1 {
            completionHandler([], nil)
            return
        }
        let directionsQuery = MKDirectionsRequest()
        directionsQuery.source = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[0].coordinate, addressDictionary: nil))
        directionsQuery.destination = MKMapItem(placemark: MKPlacemark(coordinate: waypoints[waypoints.count-1].coordinate, addressDictionary: nil))
        MKDirections(request: directionsQuery).calculate {
            response, error in
            guard error == nil, let polyline = response?.routes[0].polyline else {
                completionHandler([], error);
                return
            }
            print(response!.routes.map { "\(response!.routes.count) \($0.name) \($0.distance) \($0.expectedTravelTime)" })
            var coordinates = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
            polyline.getCoordinates(&coordinates, range: NSMakeRange(0, polyline.pointCount))
            self.describeRoute(routeCoordinates: coordinates) {
                response, error in
                guard error == nil else {
                    completionHandler([], error)
                    return
                }
                var segments = response
                segments[0].name = waypoints[0].name
                segments[segments.count-1].name = waypoints[waypoints.count-1].name
                completionHandler(segments, nil)
                return;
            }
        }
    }
    
    func describeRoute(routeCoordinates: [CLLocationCoordinate2D], completionHandler: @escaping ([RouteSegment], Error?) -> Void) {
        var segments = [RouteSegment]()
        if routeCoordinates.count==0 {
            print("Empty route coordinates list")
            completionHandler(segments,nil)
            return
        }
        var routePoints = SwiftSimplify.simplify(routeCoordinates, tolerance: 0.001).map { t in (t, t.projectToPoint()) }
        loadCameras {
            cameras, error  in
            guard error == nil else {
                completionHandler([], error)
                return
            }
            var alreadyMatchedCameras = Set<String>()
            for i in 0...routePoints.count-2 {
                var segmentCameras = [Camera]()
                for c in cameras {
                    if alreadyMatchedCameras.contains(c.id) { continue }
                    let distance = fabs(c.projectedPoint.distanceToSegment(a: routePoints[i].1, b: routePoints[i+1].1))
                    if distance>500 { continue }
                    if i+1 < routePoints.count-2 && distance>fabs(c.projectedPoint.distanceToSegment(a: routePoints[i+1].1, b: routePoints[i+2].1)) { continue }
                    alreadyMatchedCameras.insert(c.id)
                    segmentCameras.append(c)
                }
                segmentCameras.sort { a, b in a.coordinates.distanceFrom(destination: routePoints[i].0)<b.coordinates.distanceFrom(destination: routePoints[i].0) }
                var lastStart = routePoints[i].0
                for c in segmentCameras {
                    segments.append(RouteSegment(start: lastStart, end: c.coordinates, camera: c))
                    lastStart = c.coordinates
                }
                segments.append(RouteSegment(start: lastStart, end: routePoints[i+1].0, camera: nil))
            }
            completionHandler(segments, nil)
        }
    }
}
    
class RoutingServiceResponse {
    var waypoints : [MKPlacemark] = []
    var segments : [RouteSegment] = []
}
struct RouteSegment {
    var name: String = ""
    var start : CLLocationCoordinate2D
    var end : CLLocationCoordinate2D
    var camera : Camera?
    let distance : Double
    init(start : CLLocationCoordinate2D, end: CLLocationCoordinate2D, camera: Camera?) {
        self.start = start
        self.end = end
        self.camera = camera
        self.distance = start.distanceFrom(destination: end)
    }
}
