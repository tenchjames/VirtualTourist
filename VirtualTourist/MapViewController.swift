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
    @IBOutlet weak var editButton: UIBarButtonItem!
    @IBOutlet weak var mapView: MKMapView!
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "handleLongPress:")
        mapView.addGestureRecognizer(longPressRecognizer)
        mapView.delegate = self
        

        // loops over annotations in the context and places them on the map
        initAnnotations()
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
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
        } catch let error as NSError {
            // TODO: HANDLE ERROR BETTER
            print(error)
        }
        
        if let result = results?.first {
            return result
        }
        return nil
    }
    
    func deleteAnnotation(annotation: MKAnnotation) {
        let pinToDelete = annotation as! PinAnnotation
        for mapPin in mapView.annotations as! [PinAnnotation] {
            if mapPin.id == pinToDelete.id {
                mapView.removeAnnotation(mapPin)
                if let pinObject = getPinObjectByPinId(pinToDelete.id) {
                    sharedContext.deleteObject(pinObject)
                    sharedInstance.saveContext()
                }
                // TODO: handle not getting a pin back...this would be a very odd / bad case
                // because we expect this pin with this id to be in the context
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
    
    
    
    
    // sets pins on the map from the core data saved values
    func initAnnotations() {
        //let pins = fetchedResultsController.fetchedObjects as! [Pin]
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
        
        do {
            let pins = try sharedContext.executeFetchRequest(fetchRequest) as! [Pin]
            for pin in pins {
                let coordinate = CLLocationCoordinate2DMake(pin.latitude, pin.longitude)
                let annotation = PinAnnotation(id: pin.id, coordinate: coordinate)
                mapView.addAnnotation(annotation)
            }
        } catch {
            print("error loading pins")
        }
    }

}

