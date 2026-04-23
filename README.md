# ScrollView Interoperable Drag Gesture

A custom gesture that allows scroll views to be prioritized. Hitting edges makes the gesture activate. 

Using `UIGestureRecognizerRepresentable`

## Requirements
- iOS18+

## Options

- **ScrollView Priority Dragging**
  - Prioritizes the dragging gesture on a `ScrollView`, ensuring that scrolling takes precedence.
  - <img src="https://github.com/user-attachments/assets/33f3aaeb-70f7-4426-95f8-757dafae8642" width="200px">

- **ScrollView Edge Sticking**
  - Prioritizes the dragging once the scroll view's content hits its edge.
  - <img src="https://github.com/user-attachments/assets/3a90a8ad-887c-4d3a-8407-09d36077d655" width="200px">

- **Ignore ScrollView Option**
  - Ignore dragging gestures on any scroll view.
  - <img src="https://github.com/user-attachments/assets/49023e42-2a8f-4a5c-aff0-c7a802547aac" width="200px">

## Externally controlling the "sticking" state

The runtime set of edges the gesture is currently "stuck" to (`stickingEdges`)
can be observed and overridden from the outside. Writes only take effect while
`configuration.sticksToEdges` is `true`; otherwise the handler does not consult
`stickingEdges` in its pan branches.

SwiftUI:

```swift
@State private var stickingEdges: ScrollViewEdge = []

someView.gesture(
  ScrollViewInteroperableDragGesture(
    configuration: .init(ignoresScrollView: false, targetEdges: .all, sticksToEdges: true),
    stickingEdges: $stickingEdges,
    coordinateSpaceInDragging: .named("drag"),
    onChange: { _ in },
    onEnd: { _ in }
  )
)
// Read: observe `stickingEdges` to reflect the current stuck edges in UI.
// Write: assign a new value (e.g. `stickingEdges = []`) to force-clear or
// preset the stuck state — the change is picked up on the next pan frame.
```

UIKit:

```swift
let recognizer = UIScrollViewInteroperableDragGestureRecognizer(
  configuration: .init(ignoresScrollView: false, targetEdges: .all, sticksToEdges: true)
)
recognizer.onStickingEdgesChange = { edges in
  // observe current stuck edges
}
// Force-clear mid-gesture:
recognizer.stickingEdges = []
```
