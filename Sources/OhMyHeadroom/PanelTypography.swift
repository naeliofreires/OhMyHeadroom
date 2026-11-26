import CoreText
import SwiftUI

extension Font {
    static let panelHeading: Font = {
        let name = "IBMPlexSans-SmBld"
        if let url = Bundle.module.url(forResource: "IBMPlexSans-SemiBold", withExtension: "ttf", subdirectory: "Fonts") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
        guard NSFont(name: name, size: 13) != nil else { return .headline }
        return .custom(name, size: 13, relativeTo: .headline)
    }()
}
