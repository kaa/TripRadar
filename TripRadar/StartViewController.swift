//
//  StartController.swift
//  TripRadar
//
//  Created by Joakim Beijar on 16/02/16.
//  Copyright © 2016 monografi. All rights reserved.
//

import UIKit
import GooglePlaces
import GoogleMaps
import MapKit

class StartViewController: UIViewController, GMSAutocompleteViewControllerDelegate {
    
    var segments: [RouteSegment] = []

    var startAutocompleteController: GMSAutocompleteViewController!
    @IBOutlet weak var startButton: UIButton!
    @IBAction func pickStartClicked(sender: AnyObject) {
        self.present(startAutocompleteController, animated: true, completion: nil)
    }
    
    var endAutocompleteController: GMSAutocompleteViewController!
    @IBOutlet weak var endButton: UIButton!
    @IBAction func pickEndClicked(sender: AnyObject) {
        self.present(endAutocompleteController, animated: true, completion: nil)
    }
    
    @IBAction func didClickShowRoute(sender: AnyObject) {
    }
    
    func maybePlanRoute() {
        guard let start = self.start, let end = self.end else {
            return;
        }

        let alert = UIAlertController(title: nil, message: "Please wait...", preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        loadingIndicator.startAnimating();
        
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
        
        RoutingService().describeRouteBetweenPoints([start, end]) {
            response, error in

            self.dismiss(animated: false, completion: nil)
            guard error == nil else {
                print(error as Any)
                return
            }
            self.segments = response
            self.performSegue(withIdentifier: "toTable", sender: self)
        }
    }
    
    var targetField = 0
    var start: GMSPlace?
    var end: GMSPlace?

    override func viewDidLoad() {
        super.viewDidLoad()
        startButton.titleLabel?.numberOfLines = 0
        endButton.titleLabel?.numberOfLines = 0

        let filter = GMSAutocompleteFilter()
        filter.country = "FI"
        startAutocompleteController = GMSAutocompleteViewController()
        startAutocompleteController.autocompleteFilter = filter
        startAutocompleteController.delegate = self
        endAutocompleteController = GMSAutocompleteViewController()
        endAutocompleteController.autocompleteFilter = filter
        endAutocompleteController.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier=="toTable",
            let routeViewController = segue.destination as? RouteViewController {
            routeViewController.segments = self.segments
        }
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {

        if viewController===startAutocompleteController {
            self.start = place
            self.startButton.setTitleWithLabel(title: place.name, label: "START", forState: .normal)
        } else {
            self.end = place
            self.endButton.setTitleWithLabel(title: place.name, label: "DESTINATION", forState: .normal)
        }
        self.dismiss(animated: true) {
            self.maybePlanRoute()
        }
    }
    
    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        self.dismiss(animated: true, completion: nil)
    }
}

extension UIButton {
    func setTitleWithLabel(title: String, label: String, forState: UIControlState) {
        let str = NSMutableAttributedString()
        str.append(NSAttributedString(string: "\(label)\n", attributes: [
            NSAttributedStringKey.font: UIFont.systemFont(ofSize: 10)
            ]))
        str.append(NSAttributedString(string: title))
        self.titleLabel?.textAlignment = NSTextAlignment.center
        self.setAttributedTitle(str, for: forState)
    }
}
