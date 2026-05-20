import SwiftUI
import UIKit

enum AppColor {
    static let ink = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.96, blue: 0.94, alpha: 1)
            : UIColor(red: 0.10, green: 0.13, blue: 0.15, alpha: 1)
    })

    static let muted = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.68, green: 0.73, blue: 0.72, alpha: 1)
            : UIColor(red: 0.43, green: 0.47, blue: 0.48, alpha: 1)
    })

    static let leaf = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.28, green: 0.78, blue: 0.52, alpha: 1)
            : UIColor(red: 0.11, green: 0.55, blue: 0.35, alpha: 1)
    })

    static let mint = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.28, blue: 0.21, alpha: 1)
            : UIColor(red: 0.88, green: 0.96, blue: 0.91, alpha: 1)
    })

    static let peach = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.35, green: 0.24, blue: 0.14, alpha: 1)
            : UIColor(red: 1.00, green: 0.88, blue: 0.75, alpha: 1)
    })

    static let sky = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.13, green: 0.24, blue: 0.35, alpha: 1)
            : UIColor(red: 0.86, green: 0.93, blue: 1.00, alpha: 1)
    })

    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.08, blue: 0.09, alpha: 1)
            : UIColor(red: 0.98, green: 0.98, blue: 0.96, alpha: 1)
    })

    static let surface = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.13, blue: 0.14, alpha: 1)
            : UIColor.white
    })

    static let field = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.15, green: 0.17, blue: 0.18, alpha: 1)
            : UIColor(red: 0.97, green: 0.98, blue: 0.97, alpha: 1)
    })
}

struct SurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(AppColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.06), radius: 14, y: 6)
    }
}

extension View {
    func surface() -> some View {
        modifier(SurfaceModifier())
    }
}

struct AppearanceMenu: View {
    @EnvironmentObject private var store: CalorieStore

    var body: some View {
        Menu {
            Picker("Darstellung", selection: $store.appearanceMode) {
                ForEach(AppearanceMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: iconName(for: mode))
                        .tag(mode)
                }
            }
        } label: {
            Image(systemName: iconName(for: store.appearanceMode))
                .font(.body.weight(.semibold))
        }
        .accessibilityLabel("Darstellung ändern")
    }

    private func iconName(for mode: AppearanceMode) -> String {
        switch mode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
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

struct MealImageThumbnail: View {
    let imageData: Data?
    var size: CGFloat = 54

    var body: some View {
        Group {
            if let imageData,
               let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "fork.knife")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColor.leaf)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColor.mint)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
