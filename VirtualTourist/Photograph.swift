//
//  Photograph.swift
//  VirtualTourist
//
//  Created by James Tench on 9/24/15.
//  Copyright © 2015 James Tench. All rights reserved.
//

import CoreData

@objc(Photograph)



class Photograph: NSManagedObject {
    @NSManaged var title: String
    @NSManaged var urlString: String
    @NSManaged var flickrId: String
    @NSManaged var location: Pin?

    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        
        // Core Data
        let entity =  NSEntityDescription.entityForName("Photograph", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        // Dictionary
        title = dictionary["title"] as! String
        urlString = dictionary["urlString"] as! String
        
        // doubles as the file location that is saved in the document directory
        flickrId = dictionary["flickrId"] as! String
    }
    
    override func prepareForDeletion() {
        let imageName = self.flickrId
        let imagePath = getDocumentsDirectory().stringByAppendingPathComponent(imageName)
        let fileManger = NSFileManager.defaultManager()
        do {
            try fileManger.removeItemAtPath(imagePath)
        } catch _ {
            // if file is not found will throw an error...this is ok we don't want to delete a file already deleted
        }
    }
}
