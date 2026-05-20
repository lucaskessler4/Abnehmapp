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

    static let glassHighlight = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.20)
            : UIColor.white.withAlphaComponent(0.78)
    })

    static let glassStroke = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor.white.withAlphaComponent(0.15)
            : UIColor.white.withAlphaComponent(0.68)
    })
}

enum AppRadius {
    static let card: CGFloat = 24
    static let control: CGFloat = 16
    static let tile: CGFloat = 18
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppColor.paper,
                    AppColor.sky.opacity(0.46),
                    AppColor.mint.opacity(0.42),
                    AppColor.paper
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            LinearGradient(
                colors: [
                    .white.opacity(0.48),
                    .clear,
                    AppColor.peach.opacity(0.20)
                ],
                startPoint: .top,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

struct SurfaceModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                AppColor.glassHighlight,
                                .white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                    .blendMode(.screen)
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.32 : 0.10), radius: 24, y: 12)
    }
}

extension View {
    func surface() -> some View {
        modifier(SurfaceModifier())
    }

    func glassField() -> some View {
        padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .fill(.thinMaterial)
            }
            .overlay {
                RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }
    }

    func glassPill() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                Capsule(style: .continuous)
                    .fill(.thinMaterial)
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(AppColor.glassStroke, lineWidth: 1)
            }
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
                .foregroundStyle(AppColor.ink)
                .frame(width: 38, height: 38)
                .background(.thinMaterial, in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(AppColor.glassStroke, lineWidth: 1)
                }
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
                .frame(width: 38, height: 38)
                .background {
                    RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                        .fill(color.opacity(0.86))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                        .strokeBorder(.white.opacity(0.58), lineWidth: 1)
                }

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
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
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
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.tile, style: .continuous)
                .strokeBorder(AppColor.glassStroke, lineWidth: 1)
        }
    }
}
