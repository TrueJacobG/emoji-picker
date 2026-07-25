import SwiftUI

struct CustomEmojiBadge: View {
    let letter: String
    var size: CGFloat = 40
    var fontSize: CGFloat = 20

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
