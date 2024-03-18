//
//  Team+CoreDataProperties.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//
//

import Foundation
import CoreData


extension Team {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Team> {
        return NSFetchRequest<Team>(entityName: "Team")
    }

    @NSManaged public var id: UUID
    @NSManaged public var finalScore: Int32
    @NSManaged public var match: Match
    @NSManaged public var players: NSOrderedSet
    @NSManaged public var wonGames: NSOrderedSet
    @NSManaged public var wonPoints: NSOrderedSet
    @NSManaged public var wonSets: NSOrderedSet
    @NSManaged public var wonMatch: Match?

}

// MARK: Generated accessors for players
extension Team {

    @objc(insertObject:inPlayersAtIndex:)
    @NSManaged public func insertIntoPlayers(_ value: Player, at idx: Int)

    @objc(removeObjectFromPlayersAtIndex:)
    @NSManaged public func removeFromPlayers(at idx: Int)

    @objc(insertPlayers:atIndexes:)
    @NSManaged public func insertIntoPlayers(_ values: [Player], at indexes: NSIndexSet)

    @objc(removePlayersAtIndexes:)
    @NSManaged public func removeFromPlayers(at indexes: NSIndexSet)

    @objc(replaceObjectInPlayersAtIndex:withObject:)
    @NSManaged public func replacePlayers(at idx: Int, with value: Player)

    @objc(replacePlayersAtIndexes:withPlayers:)
    @NSManaged public func replacePlayers(at indexes: NSIndexSet, with values: [Player])

    @objc(addPlayersObject:)
    @NSManaged public func addToPlayers(_ value: Player)

    @objc(removePlayersObject:)
    @NSManaged public func removeFromPlayers(_ value: Player)

    @objc(addPlayers:)
    @NSManaged public func addToPlayers(_ values: NSOrderedSet)

    @objc(removePlayers:)
    @NSManaged public func removeFromPlayers(_ values: NSOrderedSet)

}

// MARK: Generated accessors for wonGames
extension Team {

    @objc(insertObject:inWonGamesAtIndex:)
    @NSManaged public func insertIntoWonGames(_ value: Game, at idx: Int)

    @objc(removeObjectFromWonGamesAtIndex:)
    @NSManaged public func removeFromWonGames(at idx: Int)

    @objc(insertWonGames:atIndexes:)
    @NSManaged public func insertIntoWonGames(_ values: [Game], at indexes: NSIndexSet)

    @objc(removeWonGamesAtIndexes:)
    @NSManaged public func removeFromWonGames(at indexes: NSIndexSet)

    @objc(replaceObjectInWonGamesAtIndex:withObject:)
    @NSManaged public func replaceWonGames(at idx: Int, with value: Game)

    @objc(replaceWonGamesAtIndexes:withWonGames:)
    @NSManaged public func replaceWonGames(at indexes: NSIndexSet, with values: [Game])

    @objc(addWonGamesObject:)
    @NSManaged public func addToWonGames(_ value: Game)

    @objc(removeWonGamesObject:)
    @NSManaged public func removeFromWonGames(_ value: Game)

    @objc(addWonGames:)
    @NSManaged public func addToWonGames(_ values: NSOrderedSet)

    @objc(removeWonGames:)
    @NSManaged public func removeFromWonGames(_ values: NSOrderedSet)

}

// MARK: Generated accessors for wonPoints
extension Team {

    @objc(insertObject:inWonPointsAtIndex:)
    @NSManaged public func insertIntoWonPoints(_ value: GamePoint, at idx: Int)

    @objc(removeObjectFromWonPointsAtIndex:)
    @NSManaged public func removeFromWonPoints(at idx: Int)

    @objc(insertWonPoints:atIndexes:)
    @NSManaged public func insertIntoWonPoints(_ values: [GamePoint], at indexes: NSIndexSet)

    @objc(removeWonPointsAtIndexes:)
    @NSManaged public func removeFromWonPoints(at indexes: NSIndexSet)

    @objc(replaceObjectInWonPointsAtIndex:withObject:)
    @NSManaged public func replaceWonPoints(at idx: Int, with value: GamePoint)

    @objc(replaceWonPointsAtIndexes:withWonPoints:)
    @NSManaged public func replaceWonPoints(at indexes: NSIndexSet, with values: [GamePoint])

    @objc(addWonPointsObject:)
    @NSManaged public func addToWonPoints(_ value: GamePoint)

    @objc(removeWonPointsObject:)
    @NSManaged public func removeFromWonPoints(_ value: GamePoint)

    @objc(addWonPoints:)
    @NSManaged public func addToWonPoints(_ values: NSOrderedSet)

    @objc(removeWonPoints:)
    @NSManaged public func removeFromWonPoints(_ values: NSOrderedSet)

}

// MARK: Generated accessors for wonSets
extension Team {

    @objc(insertObject:inWonSetsAtIndex:)
    @NSManaged public func insertIntoWonSets(_ value: MatchSet, at idx: Int)

    @objc(removeObjectFromWonSetsAtIndex:)
    @NSManaged public func removeFromWonSets(at idx: Int)

    @objc(insertWonSets:atIndexes:)
    @NSManaged public func insertIntoWonSets(_ values: [MatchSet], at indexes: NSIndexSet)

    @objc(removeWonSetsAtIndexes:)
    @NSManaged public func removeFromWonSets(at indexes: NSIndexSet)

    @objc(replaceObjectInWonSetsAtIndex:withObject:)
    @NSManaged public func replaceWonSets(at idx: Int, with value: MatchSet)

    @objc(replaceWonSetsAtIndexes:withWonSets:)
    @NSManaged public func replaceWonSets(at indexes: NSIndexSet, with values: [MatchSet])

    @objc(addWonSetsObject:)
    @NSManaged public func addToWonSets(_ value: MatchSet)

    @objc(removeWonSetsObject:)
    @NSManaged public func removeFromWonSets(_ value: MatchSet)

    @objc(addWonSets:)
    @NSManaged public func addToWonSets(_ values: NSOrderedSet)

    @objc(removeWonSets:)
    @NSManaged public func removeFromWonSets(_ values: NSOrderedSet)

}

extension Team : Identifiable {

}
