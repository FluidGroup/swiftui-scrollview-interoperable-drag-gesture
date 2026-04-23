//
//  ContentView.swift
//  Development
//

import SwiftUI
import SwiftUIScrollViewInteroperableDragGesture

struct ContentView: View {
  var body: some View {
    Picker_DiagnosticRoot()
  }
}

struct Picker_DiagnosticRoot: View {
  enum Variant: String, CaseIterable, Identifiable {
    case swiftUI = "SwiftUI"
    case uikit = "UIKit"
    var id: String { rawValue }
  }

  @State private var variant: Variant = .swiftUI

  var body: some View {
    VStack(spacing: 0) {
      Picker("", selection: $variant) {
        ForEach(Variant.allCases) { v in
          Text(v.rawValue).tag(v)
        }
      }
      .pickerStyle(.segmented)
      .padding(12)

      Divider()

      Group {
        switch variant {
        case .swiftUI:
          if #available(iOS 18, *) {
            SwiftUIDiagnosticDemo()
          } else {
            Text("Requires iOS 18+")
          }
        case .uikit:
          UIKitDiagnosticDemo()
        }
      }
    }
  }
}

// MARK: - SwiftUI variant

@available(iOS 18, *)
struct SwiftUIDiagnosticDemo: View {

  @State private var config = DemoConfig()
  @State private var translation: CGSize = .zero
  @State private var isOuterDragging: Bool = false
  @State private var scrollState = ScrollState()

  var body: some View {
    VStack(spacing: 12) {
      ConfigPanel(config: $config)
        .padding(.horizontal, 12)

      interactiveArea
        .padding(.horizontal, 24)

      DiagnosticReadout(
        translation: translation,
        scrollState: scrollState,
        isOuterDragging: isOuterDragging
      )
      .padding(.horizontal, 12)

      DemoLegend()
        .padding(.horizontal, 12)

      Spacer(minLength: 0)
    }
    .padding(.vertical, 12)
  }

  private var interactiveArea: some View {
    ZStack {
      scrollContent
        .background(Color(UIColor.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(outerBorderColor, lineWidth: 2)
        )

      EdgeMarkers(
        scrollableEdges: scrollState.scrollableEdges,
        targetEdges: config.targetEdges
      )
      .padding(-4)
    }
    .frame(height: 260)
    .offset(translation)
  }

  private var outerBorderColor: Color {
    if isOuterDragging { return .orange }
    if translation != .zero { return .blue }
    return .secondary.opacity(0.4)
  }

  private var scrollContent: some View {
    ScrollView([.horizontal, .vertical]) {
      grid
        .padding(16)
    }
    .onScrollGeometryChange(for: ScrollState.self) { g in
      ScrollState(
        offset: g.contentOffset,
        contentSize: g.contentSize,
        containerSize: g.containerSize,
        contentInset: .zero
      )
    } action: { _, new in
      scrollState = new
    }
    .gesture(
      ScrollViewInteroperableDragGesture(
        configuration: .init(
          ignoresScrollView: config.ignoresScrollView,
          targetEdges: config.targetEdges,
          sticksToEdges: config.sticksToEdges,
          edgeActivationMode: config.edgeActivationMode,
          minimumActivationDistance: config.minimumActivationDistance
        ),
        isScrollLockEnabled: $config.isScrollLockEnabled,
        coordinateSpaceInDragging: .global,
        onChange: { value in
          translation = value.translation
          isOuterDragging = value.translation != .zero
        },
        onEnd: { _ in
          translation = .zero
          isOuterDragging = false
        }
      )
    )
  }

  private var grid: some View {
    let rows = 14
    let cols = 10
    return Grid(horizontalSpacing: 4, verticalSpacing: 4) {
      ForEach(0..<rows, id: \.self) { row in
        GridRow {
          ForEach(0..<cols, id: \.self) { col in
            let n = row * cols + col
            Text("\(n)")
              .font(.caption2.monospaced())
              .frame(width: 30, height: 30)
              .background(bandColor(for: n))
              .foregroundStyle(.primary)
              .clipShape(RoundedRectangle(cornerRadius: 4))
          }
        }
      }
    }
  }

  private func bandColor(for n: Int) -> Color {
    let band = (n / 10) % 4
    switch band {
    case 0: return Color.teal.opacity(0.25)
    case 1: return Color.indigo.opacity(0.25)
    case 2: return Color.pink.opacity(0.25)
    default: return Color.green.opacity(0.25)
    }
  }
}

// MARK: - UIKit variant (placeholder here; actual implementation in UIKitDragDemo.swift)

struct UIKitDiagnosticDemo: View {
  @State private var config = DemoConfig()
  @State private var translation: CGSize = .zero
  @State private var isOuterDragging: Bool = false
  @State private var scrollState = ScrollState()

  var body: some View {
    VStack(spacing: 12) {
      ConfigPanel(config: $config)
        .padding(.horizontal, 12)

      ZStack {
        UIKitDiagnosticHostingView(
          config: config,
          translation: $translation,
          isOuterDragging: $isOuterDragging,
          scrollState: $scrollState
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
          RoundedRectangle(cornerRadius: 12)
            .strokeBorder(outerBorderColor, lineWidth: 2)
        )

        EdgeMarkers(
          scrollableEdges: scrollState.scrollableEdges,
          targetEdges: config.targetEdges
        )
        .padding(-4)
      }
      .frame(height: 260)
      .padding(.horizontal, 24)
      .offset(translation)

      DiagnosticReadout(
        translation: translation,
        scrollState: scrollState,
        isOuterDragging: isOuterDragging
      )
      .padding(.horizontal, 12)

      DemoLegend()
        .padding(.horizontal, 12)

      Spacer(minLength: 0)
    }
    .padding(.vertical, 12)
  }

  private var outerBorderColor: Color {
    if isOuterDragging { return .orange }
    if translation != .zero { return .blue }
    return .secondary.opacity(0.4)
  }
}

// MARK: - Previews

@available(iOS 18, *)
#Preview("Diagnostic") {
  ContentView()
}

@available(iOS 18, *)
#Preview("SwiftUI only") {
  SwiftUIDiagnosticDemo()
}

#Preview("UIKit only") {
  UIKitDiagnosticDemo()
}
