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

struct CameraStationsResponse : Codable {
    var features : [CameraStation]
}
struct CameraStation : Codable {
    var geometry: Geometry?
    var properties: Properties
    
    struct Properties: Codable {
        var roadStationId: Int
        var name: String
        var names: [String:String]
        var presets: [Camera]
        var nearestWeatherStationId: Int
    }

    struct Geometry : Codable {
        var coordinates: [Double]
    }

    struct Camera : Codable {
        var cameraId: String
        var imageUrl: String?
        var presentationName: String?
    }
    
    enum CodingKeys: String, CodingKey {
        case geometry
        case properties
    }
}

struct WeatherStationsResponse : Codable {
    var weatherStations: [WeatherStation]
}
struct WeatherStation : Codable {
    var id: Int
    var sensorValues: [SensorValue]
    
    struct SensorValue : Codable {
        var name: String
        var sensorValue: Double
    }
}

enum RoutingServiceError : Error {
    case unableToLoadCameraStations(networkError: Error)
    case emptyCameraStationsResponse
    case invalidCameraStationsResponse(parsingError: Error)

    case unableToLoadWeatherStations(networkError: Error)
    case emptyWeatherStationsResponse
    case invalidWeatherStationsResponse(parsingError: Error)
    
    case unableToRoute
}

class RoutingService {
    func loadCameraStations(completionHandler: @escaping ([CameraStation], RoutingServiceError?) -> Void) {
        URLSession.shared.dataTask(with: URL(string:"https://tie.digitraffic.fi/api/v1/metadata/camera-stations")!) {
            maybeData, response, error in
            guard error == nil else {
                completionHandler([], RoutingServiceError.unableToLoadCameraStations(networkError: error!))
                return;
            }
            guard let data = maybeData else {
                completionHandler([], RoutingServiceError.emptyCameraStationsResponse);
                return
            }
            do {
//                print(String(data: data, encoding: String.Encoding.utf8))
                let stationsResponse = try JSONDecoder().decode(CameraStationsResponse.self, from: data)
                completionHandler(stationsResponse.features, nil)
            } catch let parserError {
                completionHandler([], RoutingServiceError.invalidCameraStationsResponse(parsingError: parserError))
            }
        }.resume()
    }
    
    func loadWeatherData(completionHandler: @escaping ([Int: WeatherReport], RoutingServiceError?) -> Void) {
        URLSession.shared.dataTask(with: URL(string:"https://tie.digitraffic.fi/api/v1/data/weather-data")!) {
            maybeData, response, error in
            guard error == nil else {
                completionHandler([:], RoutingServiceError.unableToLoadWeatherStations(networkError: error!))
                return;
            }
            guard let data = maybeData else {
                completionHandler([:], RoutingServiceError.emptyWeatherStationsResponse);
                return
            }
            do {
                let weatherResponse = try JSONDecoder().decode(WeatherStationsResponse.self, from: data)
                let reports = weatherResponse.weatherStations.reduce([Int:WeatherReport]()) {
                    acc, report in
                    var ret = acc
                    var airTemperature = Double.signalingNaN
                    var roadTemperature = Double.signalingNaN
                    for sensor in report.sensorValues {
                        if(sensor.name=="ILMA") {
                            airTemperature = sensor.sensorValue
                        } else if(sensor.name=="TIE_1" || sensor.name=="TIE_2") {
                            roadTemperature = sensor.sensorValue
                        }
                    }
                    if(airTemperature != Double.signalingNaN && roadTemperature != Double.signalingNaN) {
                        ret[report.id] = WeatherReport(airTemperature: airTemperature, roadTemperature: roadTemperature)
                    }
                    return ret
                }
                completionHandler(reports, nil)
            } catch let parserError {
                completionHandler([:], RoutingServiceError.invalidWeatherStationsResponse(parsingError: parserError))
            }
        }.resume()
    }
    
    
    func loadStations(completionHandler: @escaping ([Station], Error?) -> Void) {
        let presetsGroup = DispatchGroup()

        var cameraError : RoutingServiceError?
        var maybeCameraStations: [CameraStation]?
        presetsGroup.enter()
        self.loadCameraStations() {
            response, error in
            if error == nil {
                maybeCameraStations = response
            } else {
                cameraError = error
            }
            presetsGroup.leave()
        }
        
        var weatherError : RoutingServiceError?
        var maybeWeatherReports: [Int:WeatherReport]?
        presetsGroup.enter()
        self.loadWeatherData {
            response, error in
            if error == nil {
                maybeWeatherReports = response
            } else {
                weatherError = error
            }
            presetsGroup.leave()
        }
  
        presetsGroup.notify(queue: DispatchQueue.main) {
            guard cameraError==nil, let cameraStations = maybeCameraStations else {
                completionHandler([],cameraError)
                return
            }
            guard weatherError==nil, let weatherReports = maybeWeatherReports else {
                completionHandler([],weatherError)
                return
            }
            let stations = cameraStations.filter { station in station.geometry != nil }.map {
                station in
                return Station(
                    id: station.properties.roadStationId,
                    name: station.properties.names["en"] ?? station.properties.names["fi"] ?? station.properties.name,
                    location: CLLocationCoordinate2D(
                        latitude: station.geometry!.coordinates[1],
                        longitude: station.geometry!.coordinates[0]
                    ),
                    weatherReport: weatherReports[station.properties.nearestWeatherStationId],
                    cameras: station.properties.presets
                        .filter { cam in cam.imageUrl != nil }
                        .map { cam in return Camera(name: cam.presentationName ?? "-", imageUrl: cam.imageUrl!, latestImage: nil) }
                )
            }
            completionHandler(stations, nil)
        }
    }

    func describeRouteBetweenPoints(waypoints: [String], completionHandler: @escaping ([RouteSegment], Error?) -> Void ) {
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

    func findWaypoints(waypoints: [String], completionHandler: @escaping ([MKPlacemark?], Error?) -> Void) {
        var storedError: Error!
        var results = [MKPlacemark?](repeating: nil, count: waypoints.count)
        let waypointGroup = DispatchGroup()
        DispatchQueue.concurrentPerform(iterations: waypoints.count) {
            i in
            let startQuery = MKLocalSearchRequest()
            startQuery.naturalLanguageQuery = waypoints[i];
            waypointGroup.enter()
            MKLocalSearch(request: startQuery).start { response, error in
                if error != nil {
                    storedError = error
                } else if let item = response?.mapItems[0] {
                    results[i] = item.placemark
                }
                waypointGroup.leave()
            }
        }
        waypointGroup.notify(queue: DispatchQueue.main) {
            completionHandler(results, storedError)
        }
    }

    func describeRouteBetweenPoints(_ waypoints: [MKPlacemark], completionHandler: @escaping ([RouteSegment], Error?) -> Void) {
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
    
    func describeRouteBetweenPoints(_ waypoints: [GMSPlace], completionHandler: @escaping ([RouteSegment], Error?) -> Void) {
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
        print("Input", routeCoordinates.count, "points")
        var routePoints = SwiftSimplify.simplify(routeCoordinates, tolerance: 0.001).map { t in (t, t.projectToPoint()) }
        print("Simplified to", routePoints.count, "points")
        loadStations {
            stations, error  in
            guard error == nil else {
                completionHandler([], error)
                return
            }
            var alreadyMatchedStations = Set<Int>()
            for i in 0...routePoints.count-2 {
                var segmentStations = [Station]()
                for station in stations {
                    if alreadyMatchedStations.contains(station.id) { continue }
                    let distance = fabs(station.projectedPoint.distanceToSegment(a: routePoints[i].1, b: routePoints[i+1].1))
                    if distance>500 { continue }
                    if i+1 < routePoints.count-2 && distance>fabs(station.projectedPoint.distanceToSegment(a: routePoints[i+1].1, b: routePoints[i+2].1)) { continue }
                    alreadyMatchedStations.insert(station.id)
                    segmentStations.append(station)
                }
                segmentStations.sort { a, b in a.location.distanceFrom(destination: routePoints[i].0)<b.location.distanceFrom(destination: routePoints[i].0) }
                var lastStart = routePoints[i].0
                for station in segmentStations {
                    segments.append(RouteSegment(name: station.name, start: lastStart, end: station.location, station: station))
                    lastStart = station.location
                }
                segments.append(RouteSegment(name: "", start: lastStart, end: routePoints[i+1].0, station: nil))
            }
            print("Output",segments.count,"segments")
            completionHandler(segments, nil)
        }
    }
}
    
class RoutingServiceResponse {
    var waypoints : [MKPlacemark] = []
    var segments : [RouteSegment] = []
}
struct RouteSegment {
    var name : String
    var start : CLLocationCoordinate2D
    var end : CLLocationCoordinate2D
    var station : Station?
    let distance : Double
    init(name: String, start : CLLocationCoordinate2D, end: CLLocationCoordinate2D, station: Station?) {
        self.name = name
        self.start = start
        self.end = end
        self.station = station
        self.distance = start.distanceFrom(destination: end)
    }
}
struct Station {
    var id: Int
    var name: String = ""
    var location: CLLocationCoordinate2D
    var weatherReport: WeatherReport?
    var cameras: [Camera] = []
    var projectedPoint : CGPoint {
        get {
            return location.projectToPoint()
        }
    }
}

struct WeatherReport {
    var airTemperature: Double
    var roadTemperature: Double
}
struct Camera {
    var name: String
    var imageUrl: String
    var latestImage: Date?
}
