//
//  Game+CoreDataProperties.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//
//

import Foundation
import CoreData


extension Game {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Game> {
        return NSFetchRequest<Game>(entityName: "Game")
    }

    @NSManaged public var isTieBreak: Bool
    @NSManaged public var inverseMatchSet: MatchSet
    @NSManaged public var nextGame: Game?
    @NSManaged public var points: NSOrderedSet
    @NSManaged public var previousGame: Game?
    @NSManaged public var winner: Team?
    
    static let kInverseMatchSet = "inverseMatchSet"

}

// MARK: Generated accessors for points
extension Game {

    @objc(insertObject:inPointsAtIndex:)
    @NSManaged public func insertIntoPoints(_ value: GamePoint, at idx: Int)

    @objc(removeObjectFromPointsAtIndex:)
    @NSManaged public func removeFromPoints(at idx: Int)

    @objc(insertPoints:atIndexes:)
    @NSManaged public func insertIntoPoints(_ values: [GamePoint], at indexes: NSIndexSet)

    @objc(removePointsAtIndexes:)
    @NSManaged public func removeFromPoints(at indexes: NSIndexSet)

    @objc(replaceObjectInPointsAtIndex:withObject:)
    @NSManaged public func replacePoints(at idx: Int, with value: GamePoint)

    @objc(replacePointsAtIndexes:withPoints:)
    @NSManaged public func replacePoints(at indexes: NSIndexSet, with values: [GamePoint])

    @objc(addPointsObject:)
    @NSManaged public func addToPoints(_ value: GamePoint)

    @objc(removePointsObject:)
    @NSManaged public func removeFromPoints(_ value: GamePoint)

    @objc(addPoints:)
    @NSManaged public func addToPoints(_ values: NSOrderedSet)

    @objc(removePoints:)
    @NSManaged public func removeFromPoints(_ values: NSOrderedSet)

}

extension Game : Identifiable {

}
