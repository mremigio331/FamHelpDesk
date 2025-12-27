import Foundation

@Observable
final class FamilySession {
    static let shared = FamilySession()

    private let familyService = FamilyService()

    var myFamilies: [String: MyFamilyItem] = [:]
    var familiesArray: [MyFamilyItem] = []
    var isFetching = false
    var errorMessage: String?

    private init() {}

    @MainActor
    func fetchMyFamilies() async {
        isFetching = true
        errorMessage = nil

        do {
            myFamilies = try await familyService.getMyFamilies()
            familiesArray = Array(myFamilies.values).sorted { $0.family.createdAt > $1.family.createdAt }
            print("✅ Fetched \(familiesArray.count) families")
        } catch {
            errorMessage = "Failed to load families: \(error.localizedDescription)"
            print("❌ Error fetching families: \(error)")
        }

        isFetching = false
    }

    @MainActor
    func refresh() async {
        await fetchMyFamilies()
    }
}
