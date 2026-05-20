import SwiftUI

enum AppColor {
    static let ink = Color(red: 0.10, green: 0.13, blue: 0.15)
    static let muted = Color(red: 0.43, green: 0.47, blue: 0.48)
    static let leaf = Color(red: 0.11, green: 0.55, blue: 0.35)
    static let mint = Color(red: 0.88, green: 0.96, blue: 0.91)
    static let peach = Color(red: 1.00, green: 0.88, blue: 0.75)
    static let sky = Color(red: 0.86, green: 0.93, blue: 1.00)
    static let paper = Color(red: 0.98, green: 0.98, blue: 0.96)
}

struct SurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(0.06), radius: 14, y: 6)
    }
}

extension View {
    func surface() -> some View {
        modifier(SurfaceModifier())
    }
}

struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String
    var color: Color = AppColor.mint

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.headline)
                .foregroundStyle(AppColor.ink)
                .frame(width: 34, height: 34)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColor.muted)
                Text(value)
                    .font(.headline)
                    .foregroundStyle(AppColor.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 0)
        }
    }
}
