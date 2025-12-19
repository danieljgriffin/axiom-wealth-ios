import SwiftUI

struct PrivacyBlur: ViewModifier {
    var isPrivate: Bool
    
    func body(content: Content) -> some View {
        content
            .blur(radius: isPrivate ? 8 : 0)
            .opacity(isPrivate ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.2), value: isPrivate)
    }
}

extension View {
    func applyPrivacyBlur(_ isPrivate: Bool) -> some View {
        modifier(PrivacyBlur(isPrivate: isPrivate))
    }
}
