//
//  MatchSet+CoreDataProperties.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//
//

import Foundation
import CoreData


extension MatchSet {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<MatchSet> {
        return NSFetchRequest<MatchSet>(entityName: "MatchSet")
    }

    @NSManaged public var games: NSOrderedSet
    @NSManaged public var match: Match
    @NSManaged public var nextSet: MatchSet?
    @NSManaged public var previousSet: MatchSet?
    @NSManaged public var winner: Team?
    
    static let kMatch = "match"

}

// MARK: Generated accessors for games
extension MatchSet {

    @objc(insertObject:inGamesAtIndex:)
    @NSManaged public func insertIntoGames(_ value: Game, at idx: Int)

    @objc(removeObjectFromGamesAtIndex:)
    @NSManaged public func removeFromGames(at idx: Int)

    @objc(insertGames:atIndexes:)
    @NSManaged public func insertIntoGames(_ values: [Game], at indexes: NSIndexSet)

    @objc(removeGamesAtIndexes:)
    @NSManaged public func removeFromGames(at indexes: NSIndexSet)

    @objc(replaceObjectInGamesAtIndex:withObject:)
    @NSManaged public func replaceGames(at idx: Int, with value: Game)

    @objc(replaceGamesAtIndexes:withGames:)
    @NSManaged public func replaceGames(at indexes: NSIndexSet, with values: [Game])

    @objc(addGamesObject:)
    @NSManaged public func addToGames(_ value: Game)

    @objc(removeGamesObject:)
    @NSManaged public func removeFromGames(_ value: Game)

    @objc(addGames:)
    @NSManaged public func addToGames(_ values: NSOrderedSet)

    @objc(removeGames:)
    @NSManaged public func removeFromGames(_ values: NSOrderedSet)

}

extension MatchSet : Identifiable {

}
