import XCTest
@testable import AgentsViewMac

final class SidecarManagerTests: XCTestCase {
    @MainActor
    func testStartTransitionsToRunningAfterHealthCheck() async throws {
        let process = TestProcessManager()
        let probe = TestHealthProbe(results: [true])
        let manager = SidecarManager(processManager: process, healthProbe: probe, executable: URL(fileURLWithPath: "/tmp/agentsview"), pollInterval: .zero, startupTimeout: 1)

        try await manager.start()

        XCTAssertEqual(manager.state, .running)
        XCTAssertEqual(process.commands, [["serve", "--background", "--host", "127.0.0.1"]])
    }
}

private final class TestProcessManager: ProcessManaging {
    var commands: [[String]] = []
    var isRunning = false
    func start(executable: URL, arguments: [String]) throws { commands.append(arguments); isRunning = true }
    func terminate(force: Bool) { isRunning = false }
}

private final class TestHealthProbe: HealthProbing {
    var results: [Bool]
    init(results: [Bool]) { self.results = results }
    func isHealthy(at url: URL) async -> Bool { results.isEmpty ? false : results.removeFirst() }
}
