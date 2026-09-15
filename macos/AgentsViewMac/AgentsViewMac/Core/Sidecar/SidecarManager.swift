import Foundation

protocol ProcessManaging: AnyObject {
    func start(executable: URL, arguments: [String]) throws
    func terminate(force: Bool)
    var isRunning: Bool { get }
}
protocol HealthProbing: AnyObject, Sendable { func isHealthy(at url: URL) async -> Bool }

private final class SystemProcessManager: ProcessManaging {
    private let process = Process()
    var isRunning: Bool { process.isRunning }
    func start(executable: URL, arguments: [String]) throws { process.executableURL = executable; process.arguments = arguments; try process.run() }
    func terminate(force: Bool) { guard process.isRunning else { return }; if force { process.terminate() } else { process.interrupt() } }
}
private final class HTTPHealthProbe: HealthProbing {
    func isHealthy(at url: URL) async -> Bool {
        var request = URLRequest(url: url); request.httpMethod = "GET"
        do { let (_, response) = try await URLSession.shared.data(for: request); return (response as? HTTPURLResponse)?.statusCode == 200 } catch { return false }
    }
}

@MainActor
final class SidecarManager {
    private let processManager: ProcessManaging
    private let healthProbe: HealthProbing
    private let executable: URL?
    private let pollInterval: Duration
    private let startupTimeout: Duration
    private let healthURL = URL(string: "http://127.0.0.1:8080/health")!
    private(set) var state: SidecarState = .stopped

    init(processManager: ProcessManaging = SystemProcessManager(), healthProbe: HealthProbing = HTTPHealthProbe(), executable: URL? = nil, pollInterval: Duration = .milliseconds(200), startupTimeout: Duration = .seconds(10)) {
        self.processManager = processManager; self.healthProbe = healthProbe; self.executable = executable; self.pollInterval = pollInterval; self.startupTimeout = startupTimeout
    }
    func start() async throws {
        guard state != .running else { return }; state = .starting
        guard let executable = executable ?? executableURL() else { state = .failed(.executableNotFound); throw SidecarError.executableNotFound }
        do { try processManager.start(executable: executable, arguments: ["serve", "--background", "--host", "127.0.0.1"]) } catch { let failure = SidecarError.startupFailed(error.localizedDescription); state = .failed(failure); throw failure }
        let deadline = ContinuousClock.now + startupTimeout
        while ContinuousClock.now < deadline {
            if await healthProbe.isHealthy(at: healthURL) { state = .running; return }
            if pollInterval > .zero { try? await Task.sleep(for: pollInterval) }
        }
        processManager.terminate(force: true); state = .failed(.startupTimedOut); throw SidecarError.startupTimedOut
    }
    func stop() async {
        guard processManager.isRunning else { state = .stopped; return }; processManager.terminate(force: false)
        if processManager.isRunning { try? await Task.sleep(for: .milliseconds(100)); if processManager.isRunning { processManager.terminate(force: true) } }; state = .stopped
    }
    private func executableURL() -> URL? {
        if let path = ProcessInfo.processInfo.environment["AGENTSVIEW_SIDECAR_PATH"], !path.isEmpty { return URL(fileURLWithPath: path) }
        return Bundle.main.url(forResource: "agentsview", withExtension: nil) ?? Bundle.main.url(forResource: "agentsview-server", withExtension: nil)
    }
}
