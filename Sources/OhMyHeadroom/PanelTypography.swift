import CoreText
import SwiftUI

extension Font {
    static let panelHeading: Font = {
        let name = "IBMPlexSans-Medm"
        if let url = Bundle.module.url(forResource: "IBMPlexSans-Medium", withExtension: "ttf", subdirectory: "Fonts") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        guard NSFont(name: name, size: 13) != nil else { return .headline.weight(.medium) }
        return .custom(name, size: 13, relativeTo: .headline)
    }()
}
