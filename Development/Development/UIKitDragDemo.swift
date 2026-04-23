import SwiftUI
import UIKit
import SwiftUIScrollViewInteroperableDragGesture

final class UIKitDragDemoViewController: UIViewController {

  private let box = UIView()
  private let scrollView = UIScrollView()
  private let content = UIStackView()
  private let gesture = UIScrollViewInteroperableDragGestureRecognizer(
    configuration: .init(
      ignoresScrollView: false,
      targetEdges: .all,
      sticksToEdges: true
    )
  )

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = UIColor.systemGroupedBackground

    box.backgroundColor = UIColor.systemGreen.withAlphaComponent(0.3)
    box.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(box)

    NSLayoutConstraint.activate([
      box.widthAnchor.constraint(equalToConstant: 240),
      box.heightAnchor.constraint(equalToConstant: 240),
      box.centerXAnchor.constraint(equalTo: view.centerXAnchor),
      box.centerYAnchor.constraint(equalTo: view.centerYAnchor),
    ])

    scrollView.backgroundColor = .systemBlue.withAlphaComponent(0.15)
    scrollView.translatesAutoresizingMaskIntoConstraints = false
    box.addSubview(scrollView)

    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 12),
      scrollView.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -12),
      scrollView.topAnchor.constraint(equalTo: box.topAnchor, constant: 12),
      scrollView.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -12),
    ])

    content.axis = .vertical
    content.spacing = 20
    content.alignment = .leading
    content.translatesAutoresizingMaskIntoConstraints = false
    scrollView.addSubview(content)

    NSLayoutConstraint.activate([
      content.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16),
      content.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16),
      content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
      content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -16),
    ])

    for _ in 0..<6 {
      let row = UIStackView()
      row.axis = .horizontal
      row.spacing = 20
      for _ in 0..<6 {
        let cell = UIView()
        cell.backgroundColor = .systemTeal
        cell.translatesAutoresizingMaskIntoConstraints = false
        cell.widthAnchor.constraint(equalToConstant: 30).isActive = true
        cell.heightAnchor.constraint(equalToConstant: 30).isActive = true
        row.addArrangedSubview(cell)
      }
      content.addArrangedSubview(row)
    }

    gesture.onChange = { [weak self] value in
      guard let self else { return }
      self.box.transform = CGAffineTransform(
        translationX: value.translation.width,
        y: value.translation.height
      )
    }
    gesture.onEnd = { [weak self] _ in
      guard let self else { return }
      UIView.animate(withDuration: 0.25) {
        self.box.transform = .identity
      }
    }
    box.addGestureRecognizer(gesture)
  }
}

struct UIKitDragDemoView: UIViewControllerRepresentable {
  func makeUIViewController(context: Context) -> UIKitDragDemoViewController {
    UIKitDragDemoViewController()
  }
  func updateUIViewController(_ uiViewController: UIKitDragDemoViewController, context: Context) {}
}

#Preview("UIKit") {
  UIKitDragDemoView()
    .ignoresSafeArea()
}
