import SwiftUI

/// SwiftUI ↔ UIKit 桥接：将 FretboardView 嵌入 SwiftUI
struct FretboardRepresentable: UIViewRepresentable {

    let viewModel: FretboardViewModel

    func makeUIView(context: Context) -> FretboardView {
        let fretboardView = FretboardView()

        fretboardView.onStringPressed = { string, fret in
            viewModel.pressString(string, fret: fret)
        }

        fretboardView.onStringReleased = { string in
            viewModel.releaseString(string)
        }

        return fretboardView
    }

    func updateUIView(_ uiView: FretboardView, context: Context) {
        uiView.updateSettings(
            scale: CGFloat(viewModel.scale),
            widthMultiplier: CGFloat(viewModel.widthMultiplier),
            offsetX: CGFloat(viewModel.offsetX)
        )
    }
}
