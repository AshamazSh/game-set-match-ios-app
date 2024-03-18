//
//  Player+CoreDataProperties.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//
//

import Foundation
import CoreData


extension Player {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Player> {
        return NSFetchRequest<Player>(entityName: "Player")
    }

    @NSManaged public var name: String
    @NSManaged public var shortName: String
    @NSManaged public var id: UUID
    @NSManaged public var servedPoints: NSOrderedSet
    @NSManaged public var team: Team

}

// MARK: Generated accessors for servedPoints
extension Player {

    @objc(insertObject:inServedPointsAtIndex:)
    @NSManaged public func insertIntoServedPoints(_ value: GamePoint, at idx: Int)

    @objc(removeObjectFromServedPointsAtIndex:)
    @NSManaged public func removeFromServedPoints(at idx: Int)

    @objc(insertServedPoints:atIndexes:)
    @NSManaged public func insertIntoServedPoints(_ values: [GamePoint], at indexes: NSIndexSet)

    @objc(removeServedPointsAtIndexes:)
    @NSManaged public func removeFromServedPoints(at indexes: NSIndexSet)

    @objc(replaceObjectInServedPointsAtIndex:withObject:)
    @NSManaged public func replaceServedPoints(at idx: Int, with value: GamePoint)

    @objc(replaceServedPointsAtIndexes:withServedPoints:)
    @NSManaged public func replaceServedPoints(at indexes: NSIndexSet, with values: [GamePoint])

    @objc(addServedPointsObject:)
    @NSManaged public func addToServedPoints(_ value: GamePoint)

    @objc(removeServedPointsObject:)
    @NSManaged public func removeFromServedPoints(_ value: GamePoint)

    @objc(addServedPoints:)
    @NSManaged public func addToServedPoints(_ values: NSOrderedSet)

    @objc(removeServedPoints:)
    @NSManaged public func removeFromServedPoints(_ values: NSOrderedSet)

}

extension Player : Identifiable {

}
