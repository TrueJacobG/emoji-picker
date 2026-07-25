import SwiftUI

struct EmojiResultRowView: View {
    let result: EmojiSearchResult
    let isSelected: Bool
    let displayLetter: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if result.isCustom {
                    CustomEmojiBadge(letter: displayLetter)
                } else {
                    Text(result.emoji.emoji)
                        .font(.system(size: 30))
                        .frame(width: 40)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.primaryName)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(result.aliasSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if result.usageCount > 0 {
                    Text("\(result.usageCount)")
                        .font(.caption.monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.primary.opacity(0.08)))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(rowBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.accentColor.opacity(0.35) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts: [String] = [result.primaryName]
        if result.isCustom {
            parts.append("custom")
        }
        if result.usageCount > 0 {
            parts.append("used \(result.usageCount) time\(result.usageCount == 1 ? "" : "s")")
        }
        return parts.joined(separator: ", ")
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.accentColor.opacity(0.18)
        }

        if result.isCustom {
            return Color.orange.opacity(0.08)
        }

        return Color.primary.opacity(0.04)
    }
}
