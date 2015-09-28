//
//  Helpers.swift
//  VirtualTourist
//
//  Created by James Tench on 9/26/15.
//  Copyright © 2015 James Tench. All rights reserved.
//

import Foundation

func getDocumentsDirectory() -> NSString {
    let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
    let documentsDirectory = paths[0]
    return documentsDirectory
}