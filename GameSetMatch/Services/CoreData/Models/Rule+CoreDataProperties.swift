//
//  Rule+CoreDataProperties.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//
//

import Foundation
import CoreData


extension Rule {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Rule> {
        return NSFetchRequest<Rule>(entityName: "Rule")
    }

    @NSManaged public var duration: Int32
    @NSManaged public var gameTieBreak: Int32
    @NSManaged public var name: String
    @NSManaged public var playMode: Int32
    @NSManaged public var tieBreak: Int32
    @NSManaged public var matches: NSSet

}

// MARK: Generated accessors for matches
extension Rule {

    @objc(addMatchesObject:)
    @NSManaged public func addToMatches(_ value: Match)

    @objc(removeMatchesObject:)
    @NSManaged public func removeFromMatches(_ value: Match)

    @objc(addMatches:)
    @NSManaged public func addToMatches(_ values: NSSet)

    @objc(removeMatches:)
    @NSManaged public func removeFromMatches(_ values: NSSet)

}

extension Rule : Identifiable {

}
