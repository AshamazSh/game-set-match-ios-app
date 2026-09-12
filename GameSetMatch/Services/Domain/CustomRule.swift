import Combine

/// Form-owned configuration; a single value is also sent by the Watch app.
@MainActor
final class CustomRule: ObservableObject {
    @Published var configuration = MatchConfiguration()
}
