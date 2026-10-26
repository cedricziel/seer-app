struct RequestSeasonSelection {
    var selected: Set<Int> = []
    private var hasInitialized = false

    mutating func update(availableSeasons: [Int]) {
        let available = Set(availableSeasons.filter { $0 > 0 })
        guard !available.isEmpty else { return }
        if hasInitialized {
            selected.formIntersection(available)
        } else {
            selected = available
            hasInitialized = true
        }
    }

    func canSubmit(isTV: Bool, isLoading: Bool, availableSeasons: [Int]) -> Bool {
        !isTV || (!isLoading && !seasonsToSubmit(availableSeasons: availableSeasons).isEmpty)
    }

    func seasonsToSubmit(availableSeasons: [Int]) -> [Int] {
        selected.intersection(availableSeasons).filter { $0 > 0 }.sorted()
    }
}
