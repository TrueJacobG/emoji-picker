import SwiftUI

struct CustomEmojiBadge: View {
    let letter: String
    let size: CGFloat
    let fontSize: CGFloat

    init(letter: String, size: CGFloat = 40, fontSize: CGFloat = 20) {
        self.letter = letter
        self.size = size
        self.fontSize = fontSize
    }

    var body: some View {
        Text(letter)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.orange)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.22)
                    .fill(Color.orange.opacity(0.12))
            )
    }
}
