//
//  PinAnnotation.swift
//  VirtualTourist
//
//  Created by James Tench on 9/23/15.
//  Copyright © 2015 James Tench. All rights reserved.
//

import MapKit


class PinAnnotation: NSObject, MKAnnotation {
    // convenience object to store additional information from pin (i.e. the id)
    var coordinate: CLLocationCoordinate2D
    var id: String
    
    
    init(id: String, coordinate: CLLocationCoordinate2D) {
        self.id = id
        self.coordinate = coordinate
    }
}
