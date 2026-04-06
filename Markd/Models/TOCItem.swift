import Foundation

struct TOCItem: Identifiable, Codable, Hashable {
    let id: String
    let level: Int
    let text: String
}
