//
//  FlickrClient.swift
//  VirtualTourist
//
//  Created by James Tench on 9/24/15.
//  Copyright © 2015 James Tench. All rights reserved.
//

import UIKit

class FlickrClient: NSObject {
    
    // shared session
    var session: NSURLSession
    
    override init() {
        session = NSURLSession.sharedSession()
        super.init()
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
        let request = NSMutableURLRequest(URL: url)
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
