import SwiftUI

extension View {
    func cardStyle() -> some View {
        self.padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}
