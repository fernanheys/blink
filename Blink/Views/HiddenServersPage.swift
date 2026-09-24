import SwiftUI

struct HiddenServersPage: View {
    let isVisible: Bool
    let back: () -> Void

    @State private var items: [HiddenServer] = []

    var body: some View {
        VStack(spacing: 0) {
            PanelPageHeader(title: "Hidden Servers", back: back)
            PanelDivider()

            if items.isEmpty {
                Text("Nothing hidden.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            row(for: item)
                            PanelDivider()
                        }
                    }
                }
            }
        }
        .onChange(of: isVisible) { _, visible in
            guard visible else { return }
            items = IgnoredServers.all()
        }
    }

    private func row(for item: HiddenServer) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.projectName)
                    .font(.system(size: 12, weight: .medium))
                Text(verbatim: "\(item.command) :\(item.port)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            RowAction(symbol: "eye", help: "Unhide") {
                IgnoredServers.unhide(id: item.id)
                items = IgnoredServers.all()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
