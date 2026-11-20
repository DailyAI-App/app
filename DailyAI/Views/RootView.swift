import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settings: ConnectionSettings
    @State private var macSelection: MacDestination = .today

    var body: some View {
        Group {
            if settings.isConfigured {
                #if os(macOS)
                macLayout
                #else
                iOSLayout
                #endif
            } else {
                SettingsView(isOnboarding: true)
            }
        }
    }

    #if os(macOS)
    private var macLayout: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.brand)
                        Image(systemName: "sparkles")
                            .foregroundStyle(.white)
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(width: 38, height: 38)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("DAILY AI")
                            .font(.system(size: 12, weight: .heavy))
                            .tracking(1.2)
                        Text("나만의 성장 공간")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 18)

                VStack(spacing: 5) {
                    ForEach(MacDestination.allCases) { destination in
                        Button {
                            macSelection = destination
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: destination.systemImage)
                                    .frame(width: 18)
                                Text(destination.title)
                                    .font(.system(size: 13, weight: macSelection == destination ? .semibold : .regular))
                                Spacer()
                            }
                            .foregroundStyle(macSelection == destination ? Color.brand : Color.primary.opacity(0.72))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(macSelection == destination ? Color.brandDim : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)

                Spacer()

                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.brandGood)
                        .frame(width: 8, height: 8)
                    Text("연결됨")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 20)
            }
            .frame(minWidth: 190, idealWidth: 210)
            .background(Color(red: 0xfd / 255, green: 0xfb / 255, blue: 0xf6 / 255))
        } detail: {
            macDetail
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var macDetail: some View {
        switch macSelection {
        case .today: TodayView()
        case .calendar: CalendarView()
        case .roadmap: RoadmapView()
        case .study: StudyView()
        case .studyPresence: StudyPresenceView()
        case .settings: SettingsView()
        }
    }
    #endif

    private var iOSLayout: some View {
        TabView {
            TodayView()
                .tabItem { Label("오늘", systemImage: "flame.fill") }
            CalendarView()
                .tabItem { Label("일정", systemImage: "calendar") }
            RoadmapView()
                .tabItem { Label("로드맵", systemImage: "map") }
            StudyView()
                .tabItem { Label("학습 코치", systemImage: "book") }
            StudyPresenceView()
                .tabItem { Label("학습 감지", systemImage: "waveform") }
            SettingsView()
                .tabItem { Label("설정", systemImage: "gearshape") }
        }
        .tint(.brand)
    }
}

private enum MacDestination: String, CaseIterable, Identifiable {
    case today
    case calendar
    case roadmap
    case study
    case studyPresence
    case settings

    var id: String { rawValue }
    var title: String {
        switch self {
        case .today: "오늘"
        case .calendar: "일정"
        case .roadmap: "로드맵"
        case .study: "학습 코치"
        case .studyPresence: "학습 감지"
        case .settings: "설정"
        }
    }
    var systemImage: String {
        switch self {
        case .today: "flame.fill"
        case .calendar: "calendar"
        case .roadmap: "map"
        case .study: "books.vertical"
        case .studyPresence: "waveform"
        case .settings: "gearshape"
        }
    }
}
