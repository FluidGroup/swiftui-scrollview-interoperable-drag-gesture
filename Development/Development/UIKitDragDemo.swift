import SwiftUI
import UIKit
import SwiftUIScrollViewInteroperableDragGesture

// MARK: - View controller

final class UIKitDiagnosticViewController: UIViewController {

  let scrollView = UIScrollView()
  private let content = UIStackView()
  let gesture = UIScrollViewInteroperableDragGestureRecognizer(
    configuration: .init(
      ignoresScrollView: false,
      targetEdges: .all,
      sticksToEdges: true
    )
  )

  var onDragChange: ((CGSize, Bool) -> Void)?
  var onDragEnd: (() -> Void)?
  var onScrollStateChange: ((ScrollState) -> Void)?

  private var contentOffsetObservation: NSKeyValueObservation?

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = UIColor.tertiarySystemBackground

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.contentInsetAdjustmentBehavior = .never
    view.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: view.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    content.axis = .vertical
    content.spacing = 4
    content.alignment = .leading
    content.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(content)

    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
      content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
      content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
    ])

    let rows = 14
    let cols = 10
    for row in 0..<rows {
      let rowStack = UIStackView()
      rowStack.axis = .horizontal
      rowStack.spacing = 4
      for col in 0..<cols {
        let n = row * cols + col
        rowStack.addArrangedSubview(makeCell(n: n))
      }
      content.addArrangedSubview(rowStack)
    }

    gesture.onChange = { [weak self] value in
      self?.onDragChange?(value.translation, value.translation != .zero)
    }
    gesture.onEnd = { [weak self] _ in
      self?.onDragEnd?()
    }
    view.addGestureRecognizer(gesture)

    contentOffsetObservation = scrollView.observe(\.contentOffset, options: [.new, .initial]) { [weak self] _, _ in
      MainActor.assumeIsolated {
        self?.reportScrollState()
      }
    }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    reportScrollState()
  }

  func setConfig(
    ignoresScrollView: Bool,
    targetEdges: ScrollViewEdge,
    sticksToEdges: Bool,
    isScrollLockEnabled: Bool
  ) {
    gesture.configuration = .init(
      ignoresScrollView: ignoresScrollView,
      targetEdges: targetEdges,
      sticksToEdges: sticksToEdges
    )
    gesture.isScrollLockEnabled = isScrollLockEnabled
  }

  private func reportScrollState() {
    let state = ScrollState(
      offset: scrollView.contentOffset,
      contentSize: scrollView.contentSize,
      containerSize: scrollView.bounds.size,
      contentInset: scrollView.adjustedContentInset
    )
    onScrollStateChange?(state)
  }

  private func makeCell(n: Int) -> UIView {
    let label = UILabel()
    label.text = "\(n)"
    label.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
    label.textAlignment = .center
    label.translatesAutoresizingMaskIntoConstraints = false
    label.backgroundColor = Self.bandColor(for: n)
    label.layer.cornerRadius = 4
    label.layer.masksToBounds = true
    NSLayoutConstraint.activate([
      label.widthAnchor.constraint(equalToConstant: 30),
      label.heightAnchor.constraint(equalToConstant: 30),
    ])
    return label
  }

  private static func bandColor(for n: Int) -> UIColor {
    switch (n / 10) % 4 {
    case 0: return UIColor.systemTeal.withAlphaComponent(0.25)
    case 1: return UIColor.systemIndigo.withAlphaComponent(0.25)
    case 2: return UIColor.systemPink.withAlphaComponent(0.25)
    default: return UIColor.systemGreen.withAlphaComponent(0.25)
    }
  }
}

// MARK: - SwiftUI bridge

struct UIKitDiagnosticHostingView: UIViewControllerRepresentable {
  let config: DemoConfig
  @Binding var translation: CGSize
  @Binding var isOuterDragging: Bool
  @Binding var scrollState: ScrollState

  func makeUIViewController(context: Context) -> UIKitDiagnosticViewController {
    let vc = UIKitDiagnosticViewController()
    vc.onDragChange = { t, dragging in
      translation = t
      isOuterDragging = dragging
    }
    vc.onDragEnd = {
      translation = .zero
      isOuterDragging = false
    }
    vc.onScrollStateChange = { state in
      scrollState = state
    }
    return vc
  }

  func updateUIViewController(_ vc: UIKitDiagnosticViewController, context: Context) {
    vc.setConfig(
      ignoresScrollView: config.ignoresScrollView,
      targetEdges: config.targetEdges,
      sticksToEdges: config.sticksToEdges,
      isScrollLockEnabled: config.isScrollLockEnabled
    )
  }
}
