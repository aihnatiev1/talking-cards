import WidgetKit
import SwiftUI

struct CardOfDayEntry: TimelineEntry {
    let date: Date
    let emoji: String
    let sound: String
    let text: String
    let colorHex: String
}

struct CardOfDayProvider: TimelineProvider {
    private let appGroupId = "group.com.talkingcards.shared"

    func placeholder(in context: Context) -> CardOfDayEntry {
        CardOfDayEntry(date: Date(), emoji: "🐱", sound: "Мяу!", text: "Так каже кіт", colorHex: "#FF6B6B")
    }

    func getSnapshot(in context: Context, completion: @escaping (CardOfDayEntry) -> Void) {
        completion(getEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CardOfDayEntry>) -> Void) {
        let entry = getEntry()
        // Update at midnight for new card of the day
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date())!)
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func getEntry() -> CardOfDayEntry {
        let defaults = UserDefaults(suiteName: appGroupId)
        let emoji = defaults?.string(forKey: "cotd_emoji") ?? "🗣️"
        let sound = defaults?.string(forKey: "cotd_sound") ?? "Картка дня"
        let text = defaults?.string(forKey: "cotd_text") ?? "Відкрий додаток!"
        let colorHex = defaults?.string(forKey: "cotd_color") ?? "#6C5CE7"
        return CardOfDayEntry(date: Date(), emoji: emoji, sound: sound, text: text, colorHex: colorHex)
    }
}

struct CardOfDayWidgetEntryView: View {
    var entry: CardOfDayProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            Color(hex: entry.colorHex).opacity(0.15)

            VStack(spacing: 6) {
                Text(entry.emoji)
                    .font(.system(size: family == .systemSmall ? 40 : 52))

                Text(entry.sound)
                    .font(.system(size: family == .systemSmall ? 16 : 20, weight: .bold))
                    .foregroundColor(Color(hex: entry.colorHex))
                    .lineLimit(1)

                if family != .systemSmall {
                    Text(entry.text)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10))
                    Text("Картка дня")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(Color(hex: entry.colorHex).opacity(0.7))
            }
            .padding()
        }
        .widgetURL(URL(string: "talkingcards://card-of-day"))
    }
}

struct CardOfDayWidget: Widget {
    let kind: String = "CardOfDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CardOfDayProvider()) { entry in
            if #available(iOS 17.0, *) {
                CardOfDayWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color(hex: entry.colorHex).opacity(0.08)
                    }
            } else {
                CardOfDayWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Картка дня")
        .description("Щоденна картка зі звуком для малят")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
