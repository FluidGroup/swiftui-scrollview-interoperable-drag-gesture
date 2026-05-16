import SwiftUI
import SwiftUIScrollViewInteroperableDragGesture

struct ContentView: View {
    @State private var offset: CGFloat = 0
    @State private var isInteroperableDragStarted = false

    init() {
        UIScrollView.appearance().bounces = false
    }

    var body: some View {
        ZStack {
            Rectangle()
                .foregroundStyle(.green)

            ScrollView {
                VStack(spacing: 0) {
                    Rectangle()
                        .foregroundStyle(.red)
                        .containerRelativeFrame(.vertical, alignment: .center)

                    Rectangle()
                        .foregroundStyle(.pink)
                        .containerRelativeFrame(.vertical, alignment: .center)
                }
            }
            .gesture(
                ScrollViewInteroperableDragGesture(
                    configuration: .init(ignoresScrollView: false, targetEdges: .vertical, sticksToEdges: true),
                    isScrollLockEnabled: $isInteroperableDragStarted,
                    coordinateSpaceInDragging: .global,
                    onChange: {
                        print($0.translation.height)
                        offset = $0.translation.height
                        isInteroperableDragStarted = true
                    },
                    onEnd: { _ in
                        offset = 0
                        isInteroperableDragStarted = false
                    }
                )
            )
            .offset(y: offset)
        }
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
