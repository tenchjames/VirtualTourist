//
//  Pin.swift
//  VirtualTourist
//
//  Created by James Tench on 9/23/15.
//  Copyright © 2015 James Tench. All rights reserved.
//

import CoreData

@objc(Pin)


class Pin: NSManagedObject {
    @NSManaged var id: String
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
    @NSManaged var photographs: [Photograph]
    
    
    // add any additional atributes below
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String: AnyObject], context: NSManagedObjectContext) {
        // track in core data
        let entity = NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // generate unique id for this pin
        id = NSUUID().UUIDString
        // set object properties with dictionary of values
        latitude = dictionary["latitude"] as! Double
        longitude = dictionary["longitude"] as! Double
    }
    
    
}
