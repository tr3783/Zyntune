import WidgetKit
import SwiftUI

// MARK: - Data Model
struct ZyntuneWidgetData {
    var currentStreak: Int
    var todayMinutes: Int
    var userName: String

    static var placeholder: ZyntuneWidgetData {
        ZyntuneWidgetData(currentStreak: 7, todayMinutes: 25, userName: "Musician")
    }

    static func load() -> ZyntuneWidgetData {
        let userDefaults = UserDefaults(suiteName: "group.com.topher.zyntune")
        let streak = userDefaults?.integer(forKey: "currentStreak") ?? 0
        let minutes = userDefaults?.integer(forKey: "todayMinutes") ?? 0
        let name = userDefaults?.string(forKey: "userName") ?? "Musician"
        return ZyntuneWidgetData(currentStreak: streak, todayMinutes: minutes, userName: name)
    }
}

// MARK: - Timeline Provider
struct ZyntuneWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> ZyntuneEntry {
        ZyntuneEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (ZyntuneEntry) -> Void) {
        let entry = ZyntuneEntry(date: Date(), data: context.isPreview ? .placeholder : .load())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ZyntuneEntry>) -> Void) {
        let data = ZyntuneWidgetData.load()
        let entry = ZyntuneEntry(date: Date(), data: data)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

// MARK: - Entry
struct ZyntuneEntry: TimelineEntry {
    let date: Date
    let data: ZyntuneWidgetData
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Widget View
struct ZyntuneWidgetEntryView: View {
    var entry: ZyntuneEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallWidgetView(data: entry.data)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "1A0A4E"), Color(hex: "2D1B69")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        case .systemMedium:
            MediumWidgetView(data: entry.data)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "1A0A4E"), Color(hex: "2D1B69")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        default:
            SmallWidgetView(data: entry.data)
                .containerBackground(for: .widget) {
                    LinearGradient(
                        colors: [Color(hex: "1A0A4E"), Color(hex: "2D1B69")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
        }
    }
}

// MARK: - Small Widget
struct SmallWidgetView: View {
    let data: ZyntuneWidgetData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Color(hex: "9B59B6"))
                Text("Zyntune")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(Color(hex: "9B59B6"))
                Spacer()
            }
            Spacer()
            HStack(alignment: .bottom) {
                Text("🔥")
                    .font(.system(size: 28))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(data.currentStreak)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    Text("day streak")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            HStack {
                Image(systemName: "timer")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "00BFA5"))
                Text("\(data.todayMinutes) min today")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "00BFA5"))
            }
        }
        .padding(14)
    }
}

// MARK: - Medium Widget
struct MediumWidgetView: View {
    let data: ZyntuneWidgetData

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "music.note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "9B59B6"))
                    Text("Zyntune")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(hex: "9B59B6"))
                }
                Spacer()
                Text("🔥")
                    .font(.system(size: 32))
                Text("\(data.currentStreak)")
                    .font(.system(size: 36, weight: .black))
                    .foregroundColor(.white)
                Text("day streak")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

            Rectangle()
                .fill(Color(hex: "6B21FF").opacity(0.4))
                .frame(width: 1)
                .padding(.vertical, 16)

            VStack(alignment: .leading, spacing: 12) {
                StatRow(icon: "timer", color: Color(hex: "00BFA5"), value: "\(data.todayMinutes)", label: "min today")
                StatRow(icon: "person.fill", color: Color(hex: "9B59B6"), value: data.userName, label: "")
                Text(data.todayMinutes == 0 ? "Practice today! 🎵" : "Keep it up! 💪")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(label.isEmpty ? value : "\(value) \(label)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
    }
}

// MARK: - Widget Configuration
@main
struct ZyntuneWidget: Widget {
    let kind: String = "ZyntuneWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ZyntuneWidgetProvider()) { entry in
            ZyntuneWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Zyntune")
        .description("Track your practice streak and today's minutes.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}