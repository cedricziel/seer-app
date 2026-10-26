import Foundation

struct DownloadStartClaims {
    private var tokens: [UUID: UUID] = [:]

    mutating func begin(_ downloadID: UUID) -> UUID {
        let token = UUID()
        tokens[downloadID] = token
        return token
    }

    func isCurrent(_ token: UUID, for downloadID: UUID) -> Bool {
        tokens[downloadID] == token
    }

    mutating func invalidate(_ downloadID: UUID) {
        tokens[downloadID] = nil
    }

    mutating func invalidateAll() {
        tokens.removeAll()
    }

    mutating func finish(_ token: UUID, for downloadID: UUID) {
        if isCurrent(token, for: downloadID) {
            invalidate(downloadID)
        }
    }
}
