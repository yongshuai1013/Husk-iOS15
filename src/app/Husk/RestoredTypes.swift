
// MARK: - LibraryFilter (從上游恢復)
enum LibraryFilter: String, CaseIterable, Identifiable {
    case all, games, apps
    var id: String { rawValue }
    var title: String {
        switch self {
        case .all: return "All"
        case .games: return "Games"
        case .apps: return "Apps"
        }
    }
}

// MARK: - ItemIcon (從上游恢復)
struct ItemIcon: View {
    let item: LibraryItem
    let size: CGFloat

    var body: some View {
        if item == .android {
            AndroidMark(size: size)
        } else {
            AppIcon(path: item.iconPath, size: size)
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.225, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

// MARK: - HomeView (從上游恢復)
struct HomeView: View {
    @ObservedObject private var router = Router.shared
    @ObservedObject private var store = TranslationLayerStore.shared
    @ObservedObject private var host = AndroidHost.shared
    @ObservedObject private var jit = JITCoordinator.shared
    @ObservedObject private var incoming = IncomingFiles.shared
    @Environment(\.colorScheme) private var scheme

    /// Everything, most recent first.
    private var all: [LibraryItem] { Launcher.byRecent(Launcher.items(store: store, host: host)) }

    var body: some View {
        NavigationView(path: $router.home) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        if let icon = HuskAppIcon.current.preview(dark: scheme == .dark) {
                            Image(uiImage: icon)
                                .resizable()
                                .frame(width: 34, height: 34)
                                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        }
                        Text("Husk")
                            .font(.system(size: 28, weight: .heavy, design: .rounded))
                        Spacer()
                        HeaderButton(systemImage: "plus") { router.addSomething() }
                            .accessibilityLabel("Add a Game or App")
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 6)

                    if let busy = incoming.preparing { BusyStrip(text: busy) }
                    if let busy = store.busy { BusyStrip(text: busy) }
                    if let busy = host.busy { BusyStrip(text: busy) }

                    let items = all
                    let lead = items.first { $0.lastUsed != nil } ?? items.first
                    VStack(spacing: 12) {
                        if let lead { LeadTile(item: lead) } else { WelcomeCard() }
                        HStack(spacing: 12) {
                            JITTile()
                            DownloadsTile()
                        }
                        AndroidTile()
                    }
                    if let error = jit.error, !Launcher.jitOn {
                        Text(error).font(.caption).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }

                    let rest = items.filter { $0 != lead }
                    if !rest.isEmpty {
                        ShelfHeader(title: "Library") { router.showLibrary(.all) }
                            .padding(.horizontal, 4)
                            .padding(.top, 6)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                            ForEach(rest.prefix(UIDevice.current.userInterfaceIdiom == .pad ? 16 : 8)) { item in
                                NavigationLink(value: item.route) { LibrarySquare(item: item) }
                                    .buttonStyle(CardButtonStyle())
                                    .accessibilityLabel(item.title)
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 32)
                .id(jit.attachGeneration)
            }
            .scrollIndicators(.hidden)
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .libraryDestinations()
        }
    }
}
