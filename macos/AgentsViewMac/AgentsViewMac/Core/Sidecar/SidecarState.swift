import Foundation

enum SidecarState: Equatable {
    case stopped
    case starting
    case running
    case failed(SidecarError)
}

enum SidecarError: Error, Equatable {
    case executableNotFound
    case startupFailed(String)
    case startupTimedOut
}
