import SwiftUI

extension Color {
    static let brand = Color(red: 0x67 / 255, green: 0x70 / 255, blue: 0xde / 255)
    static let brandDim = Color(red: 0x67 / 255, green: 0x70 / 255, blue: 0xde / 255).opacity(0.10)
    static let brandDanger = Color(red: 0xd9 / 255, green: 0x3b / 255, blue: 0x56 / 255) // --danger
    static let brandGood = Color(red: 0x2f / 255, green: 0x9e / 255, blue: 0x5c / 255)
    static let bentoLavender = Color(red: 0xee / 255, green: 0xeb / 255, blue: 0xfc / 255)
    static let bentoBlue = Color(red: 0xe9 / 255, green: 0xf3 / 255, blue: 0xff / 255)
    static let bentoYellow = Color(red: 0xff / 255, green: 0xf4 / 255, blue: 0xce / 255)
    static let bentoMint = Color(red: 0xe8 / 255, green: 0xf7 / 255, blue: 0xed / 255)
    static let bentoPink = Color(red: 0xff / 255, green: 0xec / 255, blue: 0xf1 / 255)

    static var cardBackground: Color {
        #if os(macOS)
        Color(red: 1.0, green: 0.995, blue: 0.985)
        #else
        Color(red: 1.0, green: 0.995, blue: 0.985)
        #endif
    }

    static var raisedBackground: Color {
        #if os(macOS)
        Color(red: 0xfc / 255, green: 0xf4 / 255, blue: 0xea / 255)
        #else
        Color(red: 0xfc / 255, green: 0xf4 / 255, blue: 0xea / 255)
        #endif
    }

    static var pageBackground: Color {
        #if os(macOS)
        Color(red: 0xfb / 255, green: 0xf8 / 255, blue: 0xf2 / 255)
        #else
        Color(red: 0xfb / 255, green: 0xf8 / 255, blue: 0xf2 / 255)
        #endif
    }

    static var hairline: Color { Color.primary.opacity(0.08) }
}

// MARK: - Card (matches web's .card: radius-lg, subtle border + shadow)

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Color.primary.opacity(0.055), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.045), radius: 18, y: 8)
    }
}

extension View {
    func cardStyle() -> some View { modifier(CardStyle()) }
}

// MARK: - Eyebrow (matches web's .eyebrow: small accent uppercase label)

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Color.brand)
            .tracking(0.6)
    }
}

// MARK: - Chip button (matches web's .chip / .chip-active)

struct ChipButtonStyle: ButtonStyle {
    var selected: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? Color.brandDim : Color.raisedBackground)
            .foregroundStyle(selected ? Color.brand : Color.primary.opacity(0.75))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(selected ? Color.brand.opacity(0.5) : Color.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ChipButtonStyle {
    static func chip(selected: Bool = false) -> ChipButtonStyle { ChipButtonStyle(selected: selected) }
}

// MARK: - Primary button (matches web's .btn-primary)

struct PrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false
    var tint: Color = .brand

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .background(
                LinearGradient(colors: [tint, tint.opacity(0.82)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: tint.opacity(configuration.isPressed ? 0.12 : 0.22), radius: configuration.isPressed ? 4 : 8, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(fullWidth: Bool = false, tint: Color = .brand) -> PrimaryButtonStyle {
        PrimaryButtonStyle(fullWidth: fullWidth, tint: tint)
    }
}

// MARK: - Danger text button (matches web's .btn-text-danger)

struct TextDangerButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(configuration.isPressed ? Color.brandDanger : Color.primary.opacity(0.55))
    }
}

extension ButtonStyle where Self == TextDangerButtonStyle {
    static var textDanger: TextDangerButtonStyle { TextDangerButtonStyle() }
}

// MARK: - Section heading (eyebrow + title, optional trailing accessory)

struct SectionHeading<Trailing: View>: View {
    let eyebrow: String
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Eyebrow(text: eyebrow)
                Text(title).font(.system(size: 16, weight: .semibold))
            }
            Spacer()
            trailing
        }
    }
}

extension SectionHeading where Trailing == EmptyView {
    init(eyebrow: String, title: String) {
        self.eyebrow = eyebrow
        self.title = title
        self.trailing = EmptyView()
    }
}

// MARK: - a wrapping row of chip buttons (matches web's .control-group)

struct FlowChips<Item: Hashable>: View {
    let items: [Item]
    let label: (Item) -> String
    let isSelected: (Item) -> Bool
    let onSelect: (Item) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button(label(item)) { onSelect(item) }
                    .buttonStyle(.chip(selected: isSelected(item)))
            }
        }
    }
}

// MARK: - minute formatting (matches the web's formatMinutes)

func formatMinutes(_ total: Int) -> String {
    guard total > 0 else { return "0분" }
    let hours = total / 60
    let minutes = total % 60
    if hours == 0 { return "\(minutes)분" }
    if minutes == 0 { return "\(hours)시간" }
    return "\(hours)시간 \(minutes)분"
}

struct PageHeader: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                Eyebrow(text: eyebrow)
                Text(title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 6)
        .padding(.horizontal, 2)
    }
}
