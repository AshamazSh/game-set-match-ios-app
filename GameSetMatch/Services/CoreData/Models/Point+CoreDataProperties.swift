//
//  Point+CoreDataProperties.swift
//  GameSetMatch
//
//  Created by Ashamaz on 7/3/24.
//
//

import Foundation
import CoreData


extension Point {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Point> {
        return NSFetchRequest<Point>(entityName: "GamePoint")
    }

    @NSManaged public var game: Game?
    @NSManaged public var nextPoint: Point?
    @NSManaged public var previousPoint: Point?
    @NSManaged public var servedBy: Player?
    @NSManaged public var winner: Team?

}

extension Point : Identifiable {

}
