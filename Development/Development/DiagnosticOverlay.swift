import SwiftUI
import SwiftUIScrollViewInteroperableDragGesture

enum TargetEdgesOption: String, CaseIterable, Identifiable {
  case all, vertical, horizontal, top, bottom, left, right

  var id: String { rawValue }

  var scrollViewEdge: ScrollViewEdge {
    switch self {
    case .all: return .all
    case .vertical: return .vertical
    case .horizontal: return .horizontal
    case .top: return .top
    case .bottom: return .bottom
    case .left: return .left
    case .right: return .right
    }
  }

  var label: String {
    switch self {
    case .all: return ".all"
    case .vertical: return ".vertical"
    case .horizontal: return ".horizontal"
    case .top: return "[.top]"
    case .bottom: return "[.bottom]"
    case .left: return "[.left]"
    case .right: return "[.right]"
    }
  }
}

struct DemoConfig: Equatable {
  var sticksToEdges: Bool = true
  var ignoresScrollView: Bool = false
  var targetEdgesOption: TargetEdgesOption = .all
  var isScrollLockEnabled: Bool = false

  var targetEdges: ScrollViewEdge { targetEdgesOption.scrollViewEdge }
}

struct ScrollState: Equatable {
  var offset: CGPoint = .zero
  var contentSize: CGSize = .zero
  var containerSize: CGSize = .zero
  var contentInset: UIEdgeInsets = .zero

  // Mirror of the library's internal `UIScrollView.scrollableEdges` logic.
  var scrollableEdges: ScrollViewEdge {
    var edges: ScrollViewEdge = []
    if offset.y > -contentInset.top { edges.insert(.top) }
    if offset.x > -contentInset.left { edges.insert(.left) }
    if offset.y + containerSize.height < contentSize.height + contentInset.bottom { edges.insert(.bottom) }
    if offset.x + containerSize.width < contentSize.width + contentInset.right { edges.insert(.right) }
    return edges
  }
}

struct ConfigPanel: View {
  @Binding var config: DemoConfig

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Toggle("sticksToEdges", isOn: $config.sticksToEdges)
      Toggle("ignoresScrollView", isOn: $config.ignoresScrollView)
      Toggle("isScrollLockEnabled", isOn: $config.isScrollLockEnabled)
      HStack {
        Text("targetEdges")
        Spacer()
        Picker("", selection: $config.targetEdgesOption) {
          ForEach(TargetEdgesOption.allCases) { option in
            Text(option.label).tag(option)
          }
        }
        .pickerStyle(.menu)
        .labelsHidden()
      }
    }
    .font(.caption.monospaced())
    .padding(12)
    .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
  }
}

struct DiagnosticReadout: View {
  let translation: CGSize
  let scrollState: ScrollState
  let isOuterDragging: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      row("translation", value: "(\(format(translation.width)), \(format(translation.height)))")
      row("scrollOffset", value: "(\(format(scrollState.offset.x)), \(format(scrollState.offset.y)))")
      row("scrollable", value: edgesLabel(scrollState.scrollableEdges))
      row("outerDragging", value: isOuterDragging ? "YES" : "no")
    }
    .font(.caption.monospaced())
    .padding(12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(UIColor.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
  }

  private func row(_ label: String, value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label)
        .foregroundStyle(.secondary)
        .frame(width: 110, alignment: .leading)
      Text(value)
    }
  }

  private func format(_ x: CGFloat) -> String {
    String(format: "%.0f", x)
  }

  private func edgesLabel(_ edges: ScrollViewEdge) -> String {
    if edges.isEmpty { return "[]" }
    return "[\(edges.description)]"
  }
}

struct EdgeMarkers: View {
  let scrollableEdges: ScrollViewEdge
  let targetEdges: ScrollViewEdge

  var body: some View {
    // The marker shows whether the scroll view can still scroll in that
    // direction. A filled dot means "at this edge (cannot scroll further)",
    // which is when the outer drag can take over. If that edge is also in
    // targetEdges, we highlight it as an accent to signal it is "armed".
    GeometryReader { _ in
      ZStack {
        marker(for: .top)
          .frame(maxWidth: .infinity, alignment: .center)
          .frame(maxHeight: .infinity, alignment: .top)
          .padding(.top, 2)
        marker(for: .bottom)
          .frame(maxWidth: .infinity, alignment: .center)
          .frame(maxHeight: .infinity, alignment: .bottom)
          .padding(.bottom, 2)
        marker(for: .left)
          .frame(maxHeight: .infinity, alignment: .center)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.leading, 2)
        marker(for: .right)
          .frame(maxHeight: .infinity, alignment: .center)
          .frame(maxWidth: .infinity, alignment: .trailing)
          .padding(.trailing, 2)
      }
    }
    .allowsHitTesting(false)
  }

  private func marker(for edge: ScrollViewEdge) -> some View {
    let atEdge = scrollableEdges.contains(edge) == false
    let armed = atEdge && targetEdges.contains(edge)
    return Circle()
      .fill(color(atEdge: atEdge, armed: armed))
      .frame(width: 8, height: 8)
  }

  private func color(atEdge: Bool, armed: Bool) -> Color {
    if armed { return .orange }
    if atEdge { return .green }
    return Color.secondary.opacity(0.3)
  }
}

struct DemoLegend: View {
  var body: some View {
    VStack(alignment: .leading, spacing: 3) {
      legendRow(color: .secondary.opacity(0.3), text: "can scroll further")
      legendRow(color: .green, text: "at edge")
      legendRow(color: .orange, text: "at edge & matches targetEdges")
    }
    .font(.caption2)
    .foregroundStyle(.secondary)
  }

  private func legendRow(color: Color, text: String) -> some View {
    HStack(spacing: 6) {
      Circle().fill(color).frame(width: 8, height: 8)
      Text(text)
    }
  }
}
