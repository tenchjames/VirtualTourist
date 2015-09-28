//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by James Tench on 9/24/15.
//  Copyright © 2015 James Tench. All rights reserved.
//
import GameKit
import UIKit
import CoreData

class FlickrClient: NSObject {
    
    // shared session
    var session: NSURLSession
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    var stackManager: CoreDataStackManager {
        return CoreDataStackManager.sharedInstance()
    }
  
    // MARK: - GET
    func taskForGetMethod(parameters: [String : AnyObject], completionHandler: (result: AnyObject!, error: NSError?) -> Void) -> NSURLSessionDataTask {
        
        // 1. set parameters
        var mutableparameters = parameters
        mutableparameters[ParameterKeys.ApiKey] = ParameterValues.ApiKey
        mutableparameters[ParameterKeys.Method] = ParameterValues.SearchMethod
        mutableparameters[ParameterKeys.Extras] = ParameterValues.ExtrasUrl
        mutableparameters[ParameterKeys.SafeSearch] = ParameterValues.SafeSearch
        mutableparameters[ParameterKeys.Format] = ParameterValues.JsonDataFormat
        mutableparameters[ParameterKeys.NoJsonCallBack] = ParameterValues.JsonNoCallback

        // 2. build the url
        let urlString = Constants.BASE_URL  + escapedParameters(mutableparameters)
        let url = NSURL(string: urlString)!
        
        // 3. configure request
        let request = NSURLRequest(URL: url)
        // 4. make the request
        let task = session.dataTaskWithRequest(request) {data, response, downloadError in
            
            if let error = downloadError {
                completionHandler(result: nil, error: error)
            } else {
                // 5. & 6. Parse the data and use (send with completion handler)
                if let newData = data {
                    self.parseJSONWithCompletionHandler(newData, completionHandler: completionHandler)
                } else {
                    completionHandler(result: nil, error: NSError(domain: "VirtualTourist", code: 0, userInfo: [:]))
                }
            }
        }
        // 7. start the task
        task.resume()
        
        return task
    }
    
    
    func loadPhotosForPin(pin pin: Pin, completionHandler: (success: Bool, error: NSError?) -> Void) {
        pin.loadingNewPhotos = true
        let pages = Int(pin.lastPhotoCount) / 21
        let randomPage = GKRandomSource.sharedRandom().nextIntWithUpperBound(pages) + 1
        let latitude = pin.latitude
        let longitude = pin.longitude
        let boundingBox = FlickrClient.createBoundingBoxString(latitude, longitude: longitude)
        let parameters : [String: AnyObject] = [
            FlickrClient.ParameterKeys.BoundingBox : boundingBox,
            FlickrClient.ParameterKeys.PerPage: 21,
            FlickrClient.ParameterKeys.Page : randomPage
        ]
        
        taskForGetMethod(parameters) { results, error in
            if let error = error {
                pin.loadingNewPhotos = false
                completionHandler(success: false, error: error)
                print("error")
                return
            }
            
            
            if let results = results {
                if let photosDictionary = results.valueForKey("photos") as? [String:AnyObject] {
                    var totalPhotosVal = 0
                    if let totalPhotos = photosDictionary["total"] as? String {
                        totalPhotosVal = Int(totalPhotos)!
                        // update count so we can randomize pages we pull at this location
                        pin.lastPhotoCount = totalPhotosVal
                    }
                    if totalPhotosVal > 0 {
                        if let photosArray = photosDictionary["photo"] as? [[String: AnyObject]] {
                            for photo in photosArray {
                                let title = photo["title"] as! String
                                let urlString = photo["url_m"] as! String
                                let flickrId = photo["id"] as! String
                                let dict : [String: AnyObject] = [
                                    "title": title,
                                    "urlString": urlString,
                                    "flickrId": flickrId
                                ]
                                let newPhoto = Photograph(dictionary: dict, context: self.sharedContext)
                                newPhoto.location = pin
                            }
                        }
                    }
                }
            }
            // save the new objects in the context
            dispatch_async(dispatch_get_main_queue()) {
                self.stackManager.saveContext()
                pin.loadingNewPhotos = false
                completionHandler(success: true, error: nil)
            }
        }
    }
    
    func saveFlickrImageToDisk(photo photo: Photograph, imageData: NSData) {
        let imageName = photo.flickrId
        let imagePath = getDocumentsDirectory().stringByAppendingPathComponent(imageName)
        imageData.writeToFile(imagePath, atomically: true)
    }
    
    func getFlickrImageForPhoto(photo photo: Photograph) -> UIImage? {
        let imageName = photo.flickrId
        let imagePath = getDocumentsDirectory().stringByAppendingPathComponent(imageName)
        if let image = UIImage(contentsOfFile: imagePath) {
            return image
        }
        return nil
    }
    
    class func createBoundingBoxString(latitude: Double, longitude: Double) -> String {
        let BOUNDING_BOX_HALF_WIDTH = 1.0
        let BOUNDING_BOX_HALF_HEIGHT = 1.0
        let LAT_MIN = -90.0
        let LAT_MAX = 90.0
        let LON_MIN = -180.0
        let LON_MAX = 180.0
        /* Fix added to ensure box is bounded by minimum and maximums */
        let bottom_left_lon = max(longitude - BOUNDING_BOX_HALF_WIDTH, LON_MIN)
        let bottom_left_lat = max(latitude - BOUNDING_BOX_HALF_HEIGHT, LAT_MIN)
        let top_right_lon = min(longitude + BOUNDING_BOX_HALF_HEIGHT, LON_MAX)
        let top_right_lat = min(latitude + BOUNDING_BOX_HALF_HEIGHT, LAT_MAX)
        
        return "\(bottom_left_lon),\(bottom_left_lat),\(top_right_lon),\(top_right_lat)"
    }
    
    /* Helper function: Given a dictionary of parameters, convert to a string for a url */
    func escapedParameters(parameters: [String : AnyObject]) -> String {
        
        var urlVars = [String]()
        
        for (key, value) in parameters {
            
            /* Make sure that it is a string value */
            let stringValue = "\(value)"
            
            /* Escape it */
            let escapedValue = stringValue.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
            
            /* Append it */
            urlVars += [key + "=" + "\(escapedValue!)"]
            
        }
        
        return (!urlVars.isEmpty ? "?" : "") + urlVars.joinWithSeparator("&")
    }
    
    /* Helper: Given raw JSON, return a usable Foundation object */
    func parseJSONWithCompletionHandler(data: NSData, completionHandler: (result: AnyObject!, error: NSError?) -> Void) {
        
        let parsedResult: AnyObject?
        do {
            try parsedResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.AllowFragments)
        } catch let error as NSError {
            // TODO: better error handling
            completionHandler(result: nil, error: error)
            return
        }
        
        if let result = parsedResult {
            completionHandler(result: result, error: nil)
        }
    }
    
    class func sharedInstance() -> FlickrClient {
        struct Static {
            static let instance = FlickrClient()
        }
        return Static.instance
    }
    
}
