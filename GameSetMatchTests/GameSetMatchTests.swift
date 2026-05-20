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
    
    private func createCustomMatch(duration: Int32 = 1,
                                   playMode: CustomRule.PlayMode = .double,
                                   fortyAllRule: FortyAllRule = .advantages,
                                   deciderSetRule: DeciderSetRule = .fullSet) {
        let rule = CustomRule(duration: duration,
                              playMode: playMode,
                              fortyAllRule: fortyAllRule,
                              deciderSetRule: deciderSetRule,
                              matchType: .custom)
        matchService.createMatch(.custom, customRule: rule)
    }
    
    private func winGame(teamIndex: Int) {
        for _ in 0..<4 {
            if teamIndex == 0 {
                matchService.pointWonByTeam1()
            } else {
                matchService.pointWonByTeam2()
            }
        }
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

    func testV2GoldenPointEndsGameAtFortyForty() throws {
        createCustomMatch(playMode: .single, fortyAllRule: .goldenPoint)

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
    
    func testV2ServingOrderDoesNotResetAfterSetEnds() throws {
        createCustomMatch(duration: 3)
        
        for _ in 0..<6 {
            winGame(teamIndex: 0)
        }
        
        let state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team1.setScore.map(\.value), ["6", "0"])
        XCTAssertEqual(state.team2.setScore.map(\.value), ["0", "0"])
        XCTAssertEqual(state.team1.servingPlayer?.shortName, "P1B")
        XCTAssertNil(state.team2.servingPlayer)
    }
    
    func testV2TiebreakServingOrderStartsWithCurrentServerThenTwoEach() throws {
        createCustomMatch(duration: 3)
        
        for _ in 0..<6 {
            winGame(teamIndex: 0)
            winGame(teamIndex: 1)
        }
        
        var state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.isTieBreak, true)
        XCTAssertEqual(state.team1.servingPlayer?.shortName, "P1")
        
        matchService.pointWonByTeam1()
        state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team2.servingPlayer?.shortName, "P2")
        
        matchService.pointWonByTeam1()
        state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team2.servingPlayer?.shortName, "P2")
        
        matchService.pointWonByTeam1()
        state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team1.servingPlayer?.shortName, "P1B")
    }
    
    func testV2StartPointProgressionShowsD2AndSP() throws {
        createCustomMatch(playMode: .single, fortyAllRule: .startPoint)
        
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam2()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam2()
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam2()
        XCTAssertEqual(matchService.matchState?.team1.points, "40")
        XCTAssertEqual(matchService.matchState?.team2.points, "40")
        
        matchService.pointWonByTeam1()
        XCTAssertEqual(matchService.matchState?.team1.points, "AD")
        XCTAssertEqual(matchService.matchState?.team2.points, "-")
        
        matchService.pointWonByTeam2()
        XCTAssertEqual(matchService.matchState?.team1.points, "D2")
        XCTAssertEqual(matchService.matchState?.team2.points, "D2")
        
        matchService.pointWonByTeam1()
        matchService.pointWonByTeam2()
        XCTAssertEqual(matchService.matchState?.team1.points, "SP")
        XCTAssertEqual(matchService.matchState?.team2.points, "SP")
        
        matchService.pointWonByTeam1()
        let state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.team1.setScore.first?.value, "1")
        XCTAssertEqual(state.team2.setScore.first?.value, "0")
    }
    
    func testV2SuperTiebreakDeciderWinsSetAndMatch() throws {
        createCustomMatch(duration: 3, deciderSetRule: .superTiebreak)
        
        for _ in 0..<6 {
            winGame(teamIndex: 0)
        }
        for _ in 0..<6 {
            winGame(teamIndex: 1)
        }
        
        var state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.isTieBreak, true)
        XCTAssertEqual(state.team1.setScore.map(\.value), ["6", "0", "0"])
        XCTAssertEqual(state.team2.setScore.map(\.value), ["0", "6", "0"])
        
        for _ in 0..<10 {
            matchService.pointWonByTeam1()
        }
        
        state = try XCTUnwrap(matchService.matchState)
        XCTAssertEqual(state.isCompleted, true)
        XCTAssertEqual(state.team1.setScore.map(\.value), ["6", "0", "1"])
        XCTAssertEqual(state.team2.setScore.map(\.value), ["0", "6", "0"])
        XCTAssertEqual(state.team1.isMatchWinner, true)
    }
}
