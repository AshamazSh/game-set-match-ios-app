//
//  GameSetMatchTests.swift
//  GameSetMatchTests
//
//  Created by Ashamaz on 4/3/24.
//

import XCTest
@testable import GameSetMatch

final class GameSetMatchTests: XCTestCase {
    private var persistenceController: PersistenceController!
    private var coreDataManager: CoreDataManager!
    private var matchService: MatchService!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        let context = persistenceController.container.viewContext
        coreDataManager = CoreDataManager(context: context)
        matchService = MatchService(context: context,
                                    coreDataManager: coreDataManager,
                                    connectivityManager: ConnectivityManager())
    }

    override func tearDownWithError() throws {
        matchService = nil
        coreDataManager = nil
        persistenceController = nil
    }

    func testTennisGameAdvancesSetScoreAfterFourStraightPoints() throws {
        matchService.createMatch(.tennis,
                                 players1: [.playerOne],
                                 players2: [.playerTwo])

        matchService.pointWonByTeam1()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam1()

        let state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team1.setScore.first?.value, "1")
        XCTAssertEqual(state.team2.setScore.first?.value, "0")
        XCTAssertEqual(state.team1.points, "0")
        XCTAssertEqual(state.team2.points, "0")
    }

    func testPadelGoldenPointEndsGameAtFortyForty() throws {
        matchService.createMatch(.padel)

        matchService.pointWonByTeam1()
        matchService.pointWonByTeam2()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam2()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam2()

        XCTAssertEqual(matchService.matchState?.team1.points, "40")
        XCTAssertEqual(matchService.matchState?.team2.points, "40")
        XCTAssertEqual(matchService.matchState?.isGoldenPoint, true)

        matchService.pointWonByTeam1()

        let state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team1.setScore.first?.value, "1")
        XCTAssertEqual(state.team2.setScore.first?.value, "0")
    }

    func testUndoAfterCompletedGameRestoresPreviousPointScore() throws {
        matchService.createMatch(.tennis,
                                 players1: [.playerOne],
                                 players2: [.playerTwo])

        matchService.pointWonByTeam1()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam1()
        matchService.undoLastPoint()

        let state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team1.setScore.first?.value, "0")
        XCTAssertEqual(state.team2.setScore.first?.value, "0")
        XCTAssertEqual(state.team1.points, "40")
        XCTAssertEqual(state.team2.points, "0")
    }
}
