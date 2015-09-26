//
//  PhotoViewController.swift
//  VirtualTourist
//
//  Created by James Tench on 9/23/15.
//  Copyright © 2015 James Tench. All rights reserved.
//
import MapKit
import UIKit
import CoreData


class PhotoAlbumViewController: UIViewController, NSFetchedResultsControllerDelegate,
    UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout  {
    
    @IBOutlet weak var collectionView: UICollectionView!

    var pin: Pin!

    @IBOutlet weak var mapView: MKMapView!
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    var sharedInstance: CoreDataStackManager {
        return CoreDataStackManager.sharedInstance()
    }
    // flicker client
    let flickrClient = FlickrClient.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fetchedResultsController.delegate = self
        // let coredata handle pin management
        do {
            try fetchedResultsController.performFetch()
        } catch {}
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        getPhotos()
    }
    
    override func viewDidAppear(animated: Bool) {
        let annotation = MKPointAnnotation()
        let coordinate = CLLocationCoordinate2DMake(pin.latitude, pin.longitude)
        annotation.coordinate = coordinate
        let span = MKCoordinateSpanMake(0.035, 0.035)
        let region = MKCoordinateRegionMake(coordinate, span)
        mapView.region = region
        mapView.centerCoordinate = coordinate
        mapView.addAnnotation(annotation)
    }


    // TODO: ERROR CHECKING ETC, AND CHECKING CORE DATA FOR VALUES
    func getPhotos() {
        let photographs = fetchedResultsController.fetchedObjects as! [Photograph]
        if photographs.isEmpty && !pin.loadingNewPhotos {
            flickrClient.loadPhotosForPin(pin: pin) { success, error in
                // TODO: handle error
                if success {
                    do {
                        try self.fetchedResultsController.performFetch()
                    } catch _ {
                        print("error occurred in perform fetch")
                    }
                }
            }
        }
    }
    
    
    // MARK: fetched results controller - to handle updating our collection views
    lazy var fetchedResultsController: NSFetchedResultsController = {
        
        let fetchRequest = NSFetchRequest(entityName: "Photograph")
        fetchRequest.predicate = NSPredicate(format: "location == %@", self.pin)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        
        return fetchedResultsController
        
        }()

    

    // MARK: collection view protocol
    
    
    func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let sectionInfo = self.fetchedResultsController.sections![section]
        return sectionInfo.numberOfObjects
    }
    
    func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let photograph = fetchedResultsController.objectAtIndexPath(indexPath) as! Photograph
        let cell = collectionView.dequeueReusableCellWithReuseIdentifier("PhotoCell", forIndexPath: indexPath) as! PhotoCollectionViewCell

        cell.activityIndicator.hidesWhenStopped = true
        cell.activityIndicator.startAnimating()
        
        let savedImage = flickrClient.getFlickrImageForPhoto(photo: photograph)
        
        // check if the image is saved on disk...else load from url
        if let image = savedImage {
            cell.photoImage.image = image
            cell.activityIndicator.stopAnimating()
        } else {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)) { [unowned cell] in
                if let url = NSURL(string: photograph.urlString) {
                    if let imageData = try? NSData(contentsOfURL: url, options: []) {
                        dispatch_async(dispatch_get_main_queue(), {
                            self.flickrClient.saveFlickrImageToDisk(photo: photograph, imageData: imageData)
                            cell.photoImage.image = UIImage(data: imageData)
                            cell.activityIndicator.stopAnimating()
                            
                        })
                    }
                }
            }
        }


        return cell
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.size.width / 3, height: collectionView.frame.size.width / 3)
    }
    
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
//        let person = people[indexPath.item]
//
//        let alertController = UIAlertController(title: "Rename person", message: nil, preferredStyle: .Alert)
//        alertController.addTextFieldWithConfigurationHandler(nil)
//        alertController.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: nil))
//        alertController.addAction(UIAlertAction(title: "OK", style: .Default) {
//            [unowned self, alertController] _ in
//            let newName = alertController.textFields![0]
//            person.name = newName.text!
//            self.collectionView.reloadData()
//            })
//        presentViewController(alertController, animated: true, completion: nil)
    }
    
    
    // controller to update collection views
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        try! self.fetchedResultsController.performFetch()
        //self.collectionView.reloadData()
    }
    
    func controller(controller: NSFetchedResultsController,
        didChangeSection sectionInfo: NSFetchedResultsSectionInfo,
        atIndex sectionIndex: Int,
        forChangeType type: NSFetchedResultsChangeType) {
//            switch type {
//            case .Insert:
//                
//                self.collectionView.insertSections(NSIndexSet(index: sectionIndex))
//                
//            case .Delete:
//                self.collectionView.deleteSections(NSIndexSet(index: sectionIndex))
//                
//            default:
//                return
//            }
    }
    
    func controller(controller: NSFetchedResultsController, didChangeObject anObject: AnyObject, atIndexPath indexPath: NSIndexPath?, forChangeType type: NSFetchedResultsChangeType, newIndexPath: NSIndexPath?) {
        switch type {
            
        case .Insert:
            collectionView.insertItemsAtIndexPaths([newIndexPath!])
        case .Delete:
            collectionView.deleteItemsAtIndexPaths([indexPath!])
            
        default:
            break
        }
        
//        case .Update:
//            let cell = tableView.cellForRowAtIndexPath(indexPath!) as! TaskCancelingTableViewCell
//            let movie = controller.objectAtIndexPath(indexPath!) as! Movie
//            self.configureCell(cell, movie: movie)
//            
//        case .Move:
//            tableView.deleteRowsAtIndexPaths([indexPath!], withRowAnimation: .Fade)
//            tableView.insertRowsAtIndexPaths([newIndexPath!], withRowAnimation: .Fade)
//        }
    }
    
    
}
