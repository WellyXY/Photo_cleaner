import SwiftUI

extension Font {
    // MARK: - Telka Regular
    static func telkaRegular(size: CGFloat) -> Font {
        // 嘗試使用 Telka 字體，如果不可用則回退到系統字體
        if UIFont(name: "Telka-Regular", size: size) != nil {
            return .custom("Telka-Regular", size: size)
        } else {
            return .system(size: size, weight: .regular)
        }
    }

    // MARK: - Telka Medium
    static func telkaMedium(size: CGFloat) -> Font {
        if UIFont(name: "Telka-Medium", size: size) != nil {
            return .custom("Telka-Medium", size: size)
        } else {
            return .system(size: size, weight: .medium)
        }
    }

    // MARK: - Telka Bold
    static func telkaBold(size: CGFloat) -> Font {
        if UIFont(name: "Telka-ExtendedBold", size: size) != nil {
            return .custom("Telka-ExtendedBold", size: size)
        } else {
            return .system(size: size, weight: .bold)
        }
    }

    // MARK: - Telka Black
    static func telkaBlack(size: CGFloat) -> Font {
        if UIFont(name: "Telka-ExtendedBlack", size: size) != nil {
            return .custom("Telka-ExtendedBlack", size: size)
        } else {
            return .system(size: size, weight: .black)
        }
    }

    // MARK: - Semantic Font Styles with Telka

    // Title styles
    static var telkaLargeTitle: Font {
        return .telkaBlack(size: 34)
    }

    static var telkaTitle: Font {
        return .telkaBold(size: 28)
    }

    static var telkaTitle2: Font {
        return .telkaBold(size: 22)
    }

    static var telkaTitle3: Font {
        return .telkaMedium(size: 20)
    }

    // Headline and Body
    static var telkaHeadline: Font {
        return .telkaMedium(size: 17)
    }

    static var telkaBody: Font {
        return .telkaRegular(size: 17)
    }

    static var telkaCallout: Font {
        return .telkaRegular(size: 16)
    }

    static var telkaSubheadline: Font {
        return .telkaRegular(size: 15)
    }

    static var telkaFootnote: Font {
        return .telkaRegular(size: 13)
    }

    static var telkaCaption: Font {
        return .telkaRegular(size: 12)
    }

    static var telkaCaption2: Font {
        return .telkaRegular(size: 11)
    }
}

// MARK: - Print Available Fonts (for debugging)
func printAvailableFonts() {
    for family in UIFont.familyNames.sorted() {
        let names = UIFont.fontNames(forFamilyName: family)
        print("Family: \(family) Font names: \(names)")
    }
}
