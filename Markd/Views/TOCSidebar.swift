import SwiftUI

struct TOCSidebar: View {
    let items: [TOCItem]
    let activeId: String?
    let onSelect: (String) -> Void

    var body: some View {
        if items.isEmpty {
            ContentUnavailableView(
                "No Headings",
                systemImage: "list.bullet",
                description: Text("This document has no headings.")
            )
        } else {
            List(items, selection: Binding<String?>(
                get: { activeId },
                set: { id in
                    if let id { onSelect(id) }
                }
            )) { item in
                Text(item.text)
                    .font(fontForLevel(item.level))
                    .padding(.leading, CGFloat((item.level - 1) * 12))
                    .lineLimit(2)
                    .tag(item.id)
                    .foregroundStyle(item.id == activeId ? .primary : .secondary)
            }
            .listStyle(.sidebar)
        }
    }

    private func fontForLevel(_ level: Int) -> Font {
        switch level {
        case 1: return .headline
        case 2: return .subheadline
        default: return .body
        }
    }
}
