//
//  ContentView.swift
//  Development
//
//  Created by Muukii on 2025/04/09.
//

import SwiftUI
import SwiftUIScrollViewInteroperableDragGesture

struct ContentView: View {
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")
    }
    .padding()
  }
}

@available(iOS 18, *)
private var scrollView: some View {
  ScrollView([.horizontal, .vertical]) {
    Grid(horizontalSpacing: 20, verticalSpacing: 20) {
      ForEach(0..<4) { _ in
        GridRow {
          ForEach(0..<4) { _ in Color.teal.frame(width: 30, height: 30) }
        }
      }
    }
    .padding()
    .background(Color.red)
    .padding()
    .background(Color.blue)
    .drawingGroup()
  }
}

@available(iOS 18, *)
#Preview("Box") {
  
  @Previewable @State var offset: CGSize = .zero
  
  ZStack {
    
    Rectangle()
      .fill(.red)
    .frame(width: 200, height: 200)
    .background(Color.green.secondary)
    .padding()
    .background(Color.green.tertiary)
    .offset(offset)
    .gesture(
      ScrollViewInteroperableDragGesture(
        configuration: .init(
          ignoresScrollView: false,
          targetEdges: .all,
          sticksToEdges: false
        ),
        isScrollLockEnabled: .constant(false),
        coordinateSpaceInDragging: .global,
        onChange: { value in
          offset = value.translation
        },
        onEnd: { value in
          offset = .zero
        }
      )
    )
    .background(Color.purple.tertiary)
    
  }
}

@available(iOS 18, *)
#Preview("Normal") {

  @Previewable @State var offset: CGSize = .zero

  ZStack {

    VStack {
      scrollView
    }
    .frame(width: 200, height: 200)
    .background(Color.green.secondary)
    .padding()
    .background(Color.green.tertiary)
    .offset(offset)
    .gesture(
      ScrollViewInteroperableDragGesture(
        configuration: .init(
          ignoresScrollView: false,
          targetEdges: .all,
          sticksToEdges: false
        ),
        isScrollLockEnabled: .constant(false),
        coordinateSpaceInDragging: .global,
        onChange: { value in
          offset = value.translation
        },
        onEnd: { value in
          offset = .zero
        }
      )
    )
    .background(Color.purple.tertiary)

  }
}

@available(iOS 18, *)
#Preview("SticksToEdges") {

  @Previewable @State var offset: CGSize = .zero

  ZStack {

    VStack {
      scrollView
    }
    .frame(width: 200, height: 200)
    .background(Color.green.secondary)
    .padding()
    .background(Color.green.tertiary)
    .offset(offset)
    .gesture(
      ScrollViewInteroperableDragGesture(
        configuration: .init(ignoresScrollView: false, targetEdges: .all, sticksToEdges: false),
        coordinateSpaceInDragging: .global,
        onChange: { value in
          offset = value.translation
        },
        onEnd: { value in
          offset = .zero
        }
      )
    )
    .background(Color.purple.tertiary)

  }
}

@available(iOS 18, *)
#Preview("IgnoreScrollView") {

  @Previewable @State var offset: CGSize = .zero

  ZStack {

    VStack {
      scrollView
    }
    .frame(width: 200, height: 200)
    .background(Color.green.secondary)
    .padding()
    .background(Color.green.tertiary)
    .offset(offset)
    .gesture(
      ScrollViewInteroperableDragGesture(
        configuration: .init(ignoresScrollView: false, targetEdges: .all, sticksToEdges: false),
        coordinateSpaceInDragging: .global,
        onChange: { value in
          offset = value.translation
        },
        onEnd: { value in
          offset = .zero
        }
      )
    )
    .background(Color.purple.tertiary)

  }
}
