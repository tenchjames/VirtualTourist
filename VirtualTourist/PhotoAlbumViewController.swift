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
    @IBOutlet weak var newCollectionButton: UIButton!
    @IBOutlet weak var deleteSelectedButton: UIButton!

    var pin: Pin!
    var photosPendingDeletion = [Photograph]()
    
    @IBOutlet weak var mapView: MKMapView!
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    var stackManager: CoreDataStackManager {
        return CoreDataStackManager.sharedInstance()
    }
    // flicker client
    let flickrClient = FlickrClient.sharedInstance()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        fetchedResultsController.delegate = self
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        showNewCollectionButton()
        do {
            try self.fetchedResultsController.performFetch()
        } catch _ {
            print("error occurred in perform fetch")
        }
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

    func showNewCollectionButton() {
        newCollectionButton.hidden = false
        deleteSelectedButton.hidden = true
        newCollectionButton.enabled = true
        deleteSelectedButton.enabled = false
    }
    
    func showDeleteSelectedButton() {
        deleteSelectedButton.hidden = false
        newCollectionButton.hidden = true
        deleteSelectedButton.enabled = true
        newCollectionButton.enabled = false
    }
    

    // TODO: ERROR CHECKING ETC, AND CHECKING CORE DATA FOR VALUES
    func getPhotos() {
        
        let photographs = fetchedResultsController.fetchedObjects as! [Photograph]
        if photographs.isEmpty {
            flickrClient.loadPhotosForPin(pin: pin) { success, error in
                // TODO: handle error
                if success {
                    dispatch_async(dispatch_get_main_queue()) {
                        self.collectionView.reloadData()
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
        cell.overlayCell.alpha = 0.0
        cell.overlayCell.hidden = true
        cell.photoImage.image = UIImage(named: "placeHolder")
        configureCell(cell, photograph: photograph)

        return cell
    }
    
    func configureCell(cell: PhotoCollectionViewCell, photograph: Photograph) {
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
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAtIndexPath indexPath: NSIndexPath) -> CGSize {
        return CGSize(width: collectionView.frame.size.width / 3, height: collectionView.frame.size.width / 3)
    }
    
    
    func collectionView(collectionView: UICollectionView, didSelectItemAtIndexPath indexPath: NSIndexPath) {
        let photo = fetchedResultsController.objectAtIndexPath(indexPath) as! Photograph
        // if the photo is not in the array to delete add it, else remove it (toggle like functionality
        let cell = collectionView.cellForItemAtIndexPath(indexPath) as! PhotoCollectionViewCell
        if let photoInArray = photosPendingDeletion.indexOf(photo) {

            photosPendingDeletion.removeAtIndex(photoInArray)
            cell.overlayCell.hidden = true
            cell.overlayCell.alpha = 0.0
            
        } else {
            photosPendingDeletion.append(photo)
            cell.overlayCell.hidden = false
            cell.overlayCell.alpha = 0.5
            
        }
        
        if photosPendingDeletion.count > 0 {
            showDeleteSelectedButton()
        } else {
            showNewCollectionButton()
        }
        
    }
    
    
    // controller to update collection views
    
    func controllerWillChangeContent(controller: NSFetchedResultsController) {
        dispatch_async(dispatch_get_main_queue()) {
            self.collectionView.reloadData()
        }
    }
    
    @IBAction func newCollectionButtonTouchUp(sender: AnyObject) {
        // just for testing
        let fetchRequest = NSFetchRequest(entityName: "Photograph")
        fetchRequest.predicate = NSPredicate(format: "location == %@", pin)
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        let photosAtPin: [Photograph]?
        
        do {
            photosAtPin = try self.sharedContext.executeFetchRequest(fetchRequest) as? [Photograph]
        } catch _ {
            print("error getting photosAtPin")
            photosAtPin = nil
        }
        
        dispatch_async(dispatch_get_main_queue()) {
            if let photos = photosAtPin {
                for photo in photos {
                    self.sharedContext.deleteObject(photo)
                }
            }
            self.stackManager.saveContext()
            self.getPhotos()
        }
    }
    
    @IBAction func deleteSelectedPhotosTouchUP(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {
            for photo in self.photosPendingDeletion {
                self.sharedContext.deleteObject(photo)
            }
            self.stackManager.saveContext()
            self.showNewCollectionButton()
        }
    }

    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    
}
