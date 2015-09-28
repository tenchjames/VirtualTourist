//
//  ViewController.swift
//  VirtualTourist
//
//  Created by James Tench on 9/22/15.
//  Copyright © 2015 James Tench. All rights reserved.
//

import MapKit
import UIKit
import CoreData

class MapViewController: UIViewController, MKMapViewDelegate {
    @IBOutlet weak var mapView: MKMapView!
    
    @IBOutlet weak var deletePinsLabel: UILabel!
    var longPressRecognizer: UILongPressGestureRecognizer!
    var editMode = false
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    var sharedInstance: CoreDataStackManager {
        return CoreDataStackManager.sharedInstance()
    }
    
    var flickrClient: FlickrClient {
        return FlickrClient.sharedInstance()
    }
    
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! as NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        mapView.addGestureRecognizer(longPressRecognizer)
        mapView.delegate = self
        restoreMapRegion(false)
        
        let barButtonItem = UIBarButtonItem(title: "Edit", style: UIBarButtonItemStyle.Plain, target: self, action: "toggleEdit")
        navigationItem.rightBarButtonItem = barButtonItem
        
        // loops over annotations in the context and places them on the map
        initAnnotations()
    }

    func handleLongPress(recognizer: UILongPressGestureRecognizer) {
        if recognizer.state != UIGestureRecognizerState.Began {
            return
        }
        // if we are in edit mode, don't allow new annotations to be added
        if editMode {
            return
        }
        // get point on the map tapped
        let touchPoint = recognizer.locationInView(self.mapView)
        // convert point to CLLocationCoordinate2D
        let mapCoordinate = mapView.convertPoint(touchPoint, toCoordinateFromView: mapView)
        // create a new pin and add to the map (save in the context)
        addAnnotation(mapCoordinate)
    }
    
    func mapView(mapView: MKMapView, didAddAnnotationViews views: [MKAnnotationView]) {
        // animate the pin drop
        for view in views {
            let originalY = view.frame.origin.y
            view.frame.origin.y -= 50
            UIView.animateWithDuration(0.65, delay: 0, options: [], animations: { [unowned view] in
                view.frame.origin.y = originalY
                }, completion: nil)
        }
    }
    
    func saveMapRegion() {
        
        // Place the "center" and "span" of the map into a dictionary
        // The "span" is the width and height of the map in degrees.
        // It represents the zoom level of the map.
        
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        
        // Archive the dictionary into the filePath
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }
    
    func restoreMapRegion(animated: Bool) {
        
        // if we can unarchive a dictionary, we will use it to set the map back to its
        // previous center and span
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: animated)
        }
    }
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
    
    func mapView(mapView: MKMapView, didSelectAnnotationView view: MKAnnotationView) {
        // need to take action based on edit mode or not
        if editMode {
            deleteAnnotation(view.annotation!)
        } else {
            // extract the given pin object to pass to the controller
            let pinAnnotation = view.annotation as! PinAnnotation
            
            if let pin = getPinObjectByPinId(pinAnnotation.id) as? Pin  {
                let controller = self.storyboard?.instantiateViewControllerWithIdentifier("PhotoViewController") as! PhotoAlbumViewController
                controller.pin = pin
                let backButton = UIBarButtonItem(title: "Ok", style: .Plain, target: self, action: nil)
                self.navigationItem.backBarButtonItem = backButton
                
                self.navigationController?.pushViewController(controller, animated: true)
                mapView.deselectAnnotation(view.annotation, animated: false)
            }
        }
    }
    
    func getPinObjectByPinId(id: String) -> NSManagedObject? {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.predicate = NSPredicate(format: "id == %@", id)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        fetchRequest.fetchLimit = 1
        
        var results: [NSManagedObject]?
        
        do {
            results = try sharedContext.executeFetchRequest(fetchRequest) as? [NSManagedObject]
        } catch _ {
            // if we have error, set result should be nil
            results = nil
        }
        
        if let result = results?.first {
            return result
        }
        return nil
    }
    
    func deleteAnnotation(annotation: MKAnnotation) {
        let pinToDelete = annotation as! PinAnnotation
        // loop over map pins, when found with this id
        // remove it, then delete from context
        for mapPin in mapView.annotations as! [PinAnnotation] {
            if mapPin.id == pinToDelete.id {
                mapView.removeAnnotation(mapPin)
                if let pinObject = getPinObjectByPinId(pinToDelete.id) {
                    sharedContext.deleteObject(pinObject)
                    sharedInstance.saveContext()
                }
                return
            }
        }
    }
    
    func addAnnotation(coordinate: CLLocationCoordinate2D) {
        let latitude = coordinate.latitude as Double
        let longitude = coordinate.longitude as Double
        
        let dict = ["latitude": latitude,
            "longitude": longitude]
        let pin = Pin(dictionary: dict, context: sharedContext)
        let annotation = PinAnnotation(id: pin.id, coordinate: coordinate)
        
        mapView.addAnnotation(annotation)
        // we made changes, save the context
        preloadImagesForNewlyAddedPin(pin)
        sharedInstance.saveContext()
    }
    
    // prefetch images and their data when pin is clicked
    func preloadImagesForNewlyAddedPin(pin: Pin) {
        flickrClient.loadPhotosForPin(pin: pin) { success, error in
            
            let fetchRequest = NSFetchRequest(entityName: "Photograph")
            fetchRequest.predicate = NSPredicate(format: "location == %@", pin)
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
            
            let photosAtPin: [Photograph]?
            
            do {
                photosAtPin = try self.sharedContext.executeFetchRequest(fetchRequest) as? [Photograph]
            } catch _ {
                photosAtPin = nil
            }
            
            if let photos = photosAtPin {
                for photo in photos {
                    // get photos on background threads
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) { [unowned self] in
                        if let url = NSURL(string: photo.urlString) {
                            if let imageData = try? NSData(contentsOfURL: url, options: []) {
                                dispatch_async(dispatch_get_main_queue(), {
                                    self.flickrClient.saveFlickrImageToDisk(photo: photo, imageData: imageData)
                                })
                            }
                        }
                    }
                }
            }
        }
    }
    
    func toggleEdit() {
        editMode = !editMode
        if editMode {
            deletePinsLabel.hidden = false
            navigationItem.rightBarButtonItem?.title = "Done"
        } else {
            deletePinsLabel.hidden = true
            navigationItem.rightBarButtonItem?.title = "Edit"
        }
    }
    
    // sets pins on the map from the core data saved values
    func initAnnotations() {
        //let pins = fetchedResultsController.fetchedObjects as! [Pin]
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        let pins: [Pin]
        do {
            pins = try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
        } catch {
            pins = []
        }
        for pin in pins {
            let coordinate = CLLocationCoordinate2DMake(pin.latitude, pin.longitude)
            let annotation = PinAnnotation(id: pin.id, coordinate: coordinate)
            mapView.addAnnotation(annotation)
        }
        
    }
}

