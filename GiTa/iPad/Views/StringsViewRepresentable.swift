import SwiftUI

/// SwiftUI ↔ UIKit 桥接：将 StringsStrumsView 嵌入 SwiftUI
struct StringsViewRepresentable: UIViewRepresentable {

    let viewModel: StrummingViewModel

    func makeUIView(context: Context) -> StringsStrumsView {
        let view = StringsStrumsView()

        view.onStringPlucked = { stringIndex, amplitude in
            viewModel.pluckString(stringIndex, amplitude: amplitude)
        }

        view.onStrum = { from, to, velocity in
            viewModel.strum(from: from, to: to, velocity: velocity)
        }

        view.onKnock = {
            viewModel.knock()
        }

        return view
    }

    func updateUIView(_ uiView: StringsStrumsView, context: Context) {
        // 更新音名显示
        uiView.updateNotes(viewModel.fretState)
    }
}
