//
//  NSOrderedSet+NSManagedObject.swift
//  GameSetMatch
//
//  Created by Ashamaz on 6/3/24.
//

import Foundation

extension NSOrderedSet {
    func allObjectsOfType<T>(_ t: T.Type) -> [T] {
        var result = [T]()
        for object in self {
            if let converted = object as? T {
                result.append(converted)
            }
        }
        return result
    }
}
