//
//  GamePoint+CoreDataProperties.swift
//  GameSetMatch
//
//  Created by Ashamaz on 4/3/24.
//
//

import Foundation
import CoreData


extension GamePoint {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<GamePoint> {
        return NSFetchRequest<GamePoint>(entityName: "GamePoint")
    }

    @NSManaged public var nextPoint: GamePoint?
    @NSManaged public var previousPoint: GamePoint?
    @NSManaged public var game: Game
    @NSManaged public var servedBy: Player
    @NSManaged public var winner: Team

    static let kGame = "game"

}

extension GamePoint : Identifiable {

}
