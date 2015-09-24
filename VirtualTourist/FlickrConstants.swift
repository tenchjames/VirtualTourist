//
//  FlickrConstants.swift
//  VirtualTourist
//
//  Created by James Tench on 9/24/15.
//  Copyright © 2015 James Tench. All rights reserved.
//


extension FlickrClient {
    
    
    struct Constants {
        static let BASE_URL = "https://api.flickr.com/services/rest/"
        
    }
    
    struct ParameterKeys {
        static let Method = "method"
        static let ApiKey = "api_key"
        static let Text = "text"
        static let SafeSearch = "safe_search"
        static let Extras = "extras"
        static let Format = "format"
        static let NoJsonCallBack = "nojsoncallback"
        static let BoundingBox = "bbox"
        static let PerPage = "per_page"
    }
    
    struct ParameterValues {
        static let ApiKey = "fd3d70dba98b8e1b25469df2ff70b96e"
        static let SearchMethod = "flickr.photos.search"
        static let ExtrasUrl = "url_m"
        static let SafeSearch = "1"
        static let JsonDataFormat = "json"
        static let JsonNoCallback = "1"
    }

    // body uses some response keys
    struct JSONResponseKeys {
        static let Results = "results"
        static let CreatedAt = "createdAt"
        static let FirstName = "firstName"
        static let LastName = "lastName"
        static let Latitude = "latitude"
        static let Longitude = "longitude"
        static let MapString = "mapString"
        static let MediaURL = "mediaURL"
        static let ObjectId = "objectId"
        static let UniqueKey = "uniqueKey"
        static let UpdatedAt = "updatedAt"
    }
}

