
import SwiftUI

@available(iOS 18, *)
public struct ScrollViewInteroperableDragGesture: UIGestureRecognizerRepresentable {
  
  public struct Value: Equatable {
    
    public let translation: CGSize
    public let location: CGPoint
    fileprivate(set) public var velocity: CGSize
    
  }
  
  public struct Configuration {
    
    public var targetEdges: ScrollViewEdge
    public var ignoresScrollView: Bool
    public var sticksToEdges: Bool
    
    public init(
      ignoresScrollView: Bool,
      targetEdges: ScrollViewEdge,
      sticksToEdges: Bool      
    ) {
      self.ignoresScrollView = ignoresScrollView
      self.sticksToEdges = sticksToEdges
      self.targetEdges = targetEdges
    }
  }
  
  public final class Coordinator: NSObject, UIGestureRecognizerDelegate {
    
    struct Tracking {
      var isDraggingX: Bool = false
      var isDraggingY: Bool = false
      var currentScrollController: ScrollController?
      var initialScrollableEdges: ScrollViewEdge = []
      var translation: CGSize = .zero
      var stickingEdges: ScrollViewEdge = []
    }
    
    var tracking: Tracking = .init()
    
    private let configuration: Configuration
    
    init(configuration: Configuration) {
      self.configuration = configuration
    }
    
    func purgeTrakingState() {
      tracking = .init()
    }
    
    @objc
    public func gestureRecognizer(
      _ gestureRecognizer: UIGestureRecognizer,
      shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
      
      guard let _gestureRecognizer = gestureRecognizer as? _ScrollViewDragGestureRecognizer else {
        assertionFailure("\(gestureRecognizer)")
        return false
      }
      
      guard !(otherGestureRecognizer is UIScreenEdgePanGestureRecognizer) else {
        return false
      }
      
      if configuration.ignoresScrollView {
        if otherGestureRecognizer.view is UIScrollView {
          return false
        }
      }
      
      let result = _gestureRecognizer.trackingScrollView == otherGestureRecognizer.view
      
      return result
      
    }
    
  }
  
  private let coordinateSpaceInDragging: CoordinateSpaceProtocol
  private let _onChange: (Value) -> Void
  private let _onEnd: (Value) -> Void
  private let configuration: Configuration
  
  private let isScrollLockEnabled: Binding<Bool>
  
  public init(
    configuration: Configuration = .init(
      ignoresScrollView: false,
      targetEdges: .all,
      sticksToEdges: true
    ),
    isScrollLockEnabled: Binding<Bool> = .constant(false),
    coordinateSpaceInDragging: CoordinateSpaceProtocol,
    onChange: @escaping (Value) -> Void,
    onEnd: @escaping (Value) -> Void
  ) {
    self.configuration = configuration
    self.coordinateSpaceInDragging = coordinateSpaceInDragging
    self.isScrollLockEnabled = isScrollLockEnabled
    self._onChange = onChange
    self._onEnd = onEnd
  }
  
  public func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
    return .init(configuration: configuration)
  }
  
  public func makeUIGestureRecognizer(context: Context) -> _ScrollViewDragGestureRecognizer {
    let gesture = _ScrollViewDragGestureRecognizer()
    gesture.delegate = context.coordinator
    return gesture
  }
  
  public func handleUIGestureRecognizerAction(
    _ recognizer: _ScrollViewDragGestureRecognizer,
    context: Context
  ) {
    
    switch recognizer.state {
    case .possible:
      break
    case .began:
      if let scrollView = recognizer.trackingScrollView {
        context.coordinator.tracking.initialScrollableEdges = scrollView.scrollableEdges
      }
      fallthrough
    case .changed:
      
      func makeValue(translation: CGSize) -> Value {
        return Value(
          translation: translation,
          location: context.converter.location(in: coordinateSpaceInDragging),
          velocity: { .init(width: $0.x, height: $0.y) }(
            context.converter.velocity(in: coordinateSpaceInDragging) ?? .zero
          )
        )
      }
      
      let (panDirection, diff) = recognizer.panDirection

      if let scrollView = recognizer.trackingScrollView {
        
        let scrollController = ScrollController(scrollView: scrollView)
        
        context.coordinator.tracking.currentScrollController = scrollController
        
        let scrollableEdges = scrollView.scrollableEdges
        
        var tracking = context.coordinator.tracking
        
        defer {
          context.coordinator.tracking = tracking
        }
                       
        if isScrollLockEnabled.wrappedValue {
          scrollController.lockScrolling(direction: [.horizontal, .vertical])
          
          tracking.translation.width += diff.x
          tracking.translation.height += diff.y
          
          _onChange(makeValue(translation: tracking.translation))
          
          return
        }
                        
        // handling scrolling in scrollview
        do {
          
          if panDirection.contains(.up) {
            
            if tracking.initialScrollableEdges.contains(.bottom) == false
                && 
                (
                  (
                    tracking.initialScrollableEdges.contains(.bottom) 
                    &&
                    configuration.targetEdges.contains(.bottom) && scrollableEdges.contains(.bottom) == false
                  )
                  ||                   
                  configuration.sticksToEdges && tracking.stickingEdges.contains(.top)
                )
            {
              
              scrollController.lockScrolling(direction: .vertical)     
              
              if configuration.sticksToEdges && tracking.stickingEdges.contains(.top) == false {
                scrollController.scrollTo(edge: .bottom)
              }
              
              tracking.isDraggingY = true
              
              tracking.translation.height += diff.y
              tracking.stickingEdges.insert(.bottom)              
              _onChange(makeValue(translation: tracking.translation))
            } else {
              
              scrollController.unlockScrolling(direction: .vertical)
              tracking.isDraggingY = false
              
            }
            
          }
          
          if panDirection.contains(.down) {
                        
            if tracking.initialScrollableEdges.contains(.top) == false
                && 
                (
                  (
                    configuration.targetEdges.contains(.top) 
                    &&
                    scrollableEdges.contains(.top) == false
                  )
                  ||
                  configuration.sticksToEdges && tracking.stickingEdges.contains(.bottom)
                )
            {
              
              scrollController.lockScrolling(direction: .vertical)
              
              if configuration.sticksToEdges && tracking.stickingEdges.contains(.bottom) == false {
                scrollController.scrollTo(edge: .top)
              }
              
              tracking.translation.height += diff.y              
              tracking.isDraggingY = true
              tracking.stickingEdges.insert(.top)              
              
              _onChange(makeValue(translation: tracking.translation))
              
            } else {
              scrollController.unlockScrolling(direction: .vertical)
              tracking.isDraggingY = false
            }
          }
          
          if panDirection.contains(.left) {
            
            if tracking.initialScrollableEdges.contains(.right) == false
                &&
                (
                  (
                    configuration.targetEdges.contains(.right)                
                    && 
                    scrollableEdges.contains(.right) == false 
                  )
                  ||
                  configuration.sticksToEdges && tracking.stickingEdges.contains(.left)
                )
            {
              
              scrollController.lockScrolling(direction: .horizontal)    
              
              if configuration.sticksToEdges && tracking.stickingEdges.contains(.left) == false {
                scrollController.scrollTo(edge: .right)
              }
              
              tracking.isDraggingX = true              
              tracking.translation.width += diff.x
              tracking.stickingEdges.insert(.right)
              
              _onChange(makeValue(translation: tracking.translation))
              
            } else {
              scrollController.unlockScrolling(direction: .horizontal)
              tracking.isDraggingX = false
              
            }
            
          }
          
          if panDirection.contains(.right) {
            
            if tracking.initialScrollableEdges.contains(.right) == false 
                && 
                (
                  (
                    configuration.targetEdges.contains(.left)
                    &&
                    scrollableEdges.contains(.left) == false
                  )
                  || 
                  configuration.sticksToEdges && tracking.stickingEdges.contains(.right)
                ) {
              
              scrollController.lockScrolling(direction: .horizontal)
              
              if configuration.sticksToEdges && tracking.stickingEdges.contains(.right) == false {
                scrollController.scrollTo(edge: .left)
              }
              
              tracking.isDraggingX = true              
              tracking.translation.width += diff.x
              tracking.stickingEdges.insert(.left)
              
              _onChange(makeValue(translation: tracking.translation))
              
            } else {
              scrollController.unlockScrolling(direction: .horizontal)
              tracking.isDraggingX = false
              
            }
            
          }
        }
        
      } else {
        context.coordinator.tracking.isDraggingX = true
        context.coordinator.tracking.isDraggingY = true
        
        context.coordinator.tracking.translation.width += diff.x
        context.coordinator.tracking.translation.height += diff.y

        _onChange(makeValue(translation: context.coordinator.tracking.translation))
        
      }
      
    case .ended, .cancelled, .failed:
      
      var value = Value(
        translation: context.coordinator.tracking.translation,
        location: context.converter.location(in: coordinateSpaceInDragging),
        velocity: { .init(width: $0.x, height: $0.y) }(
          context.converter.velocity(in: coordinateSpaceInDragging) ?? .zero
        )
      )
      
      if context.coordinator.tracking.isDraggingX == false {
        value.velocity.width = 0
      }
      
      if context.coordinator.tracking.isDraggingY == false {
        value.velocity.height = 0
      }
      
      _onEnd(
        value         
      )
      
      context.coordinator.purgeTrakingState()
      
    @unknown default:
      break
    }
    
  }
  
}

public final class _ScrollViewDragGestureRecognizer: UIPanGestureRecognizer {
  
  struct PanDirection: OptionSet {
    let rawValue: Int
    
    static let up = PanDirection(rawValue: 1 << 0)
    static let down = PanDirection(rawValue: 1 << 1)
    static let left = PanDirection(rawValue: 1 << 2)
    static let right = PanDirection(rawValue: 1 << 3)
    
  }
  
  weak var trackingScrollView: UIScrollView?
  
  private var previousTranslation: CGPoint = .zero
    
  var panDirection: (PanDirection, diff: CGPoint) {
    
    let translation = self.translation(in: view)
    
    let diff = CGPoint(x: translation.x - previousTranslation.x, y: translation.y - previousTranslation.y)
    
    previousTranslation = translation
    
    var direction: PanDirection = []
    
    if diff.y > 0 {
      direction.insert(.down)
    } else if diff.y < 0 {
      direction.insert(.up)
    }
    
    if diff.x > 0 {
      direction.insert(.right)
    } else if diff.x < 0 {
      direction.insert(.left)
    }
    
    return (direction, diff)
  }
  
  public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
    trackingScrollView = event.findVerticalScrollView()
    previousTranslation = .zero
    super.touchesBegan(touches, with: event)
  }
  
  public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
    
    super.touchesMoved(touches, with: event)
  }
  
  public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesEnded(touches, with: event)
  }
  
  public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
    super.touchesCancelled(touches, with: event)
  }
  
}

extension UIEvent {
  
  @MainActor
  fileprivate func findVerticalScrollView() -> UIScrollView? {
    
    guard
      let firstTouch = allTouches?.first,
      let targetView = firstTouch.view
    else { return nil }
    
    let scrollView = Array(sequence(first: targetView, next: { $0.next }))
      .last {
        guard let scrollView = $0 as? UIScrollView else {
          return false
        }
        
        @MainActor
        func isScrollable(scrollView: UIScrollView) -> Bool {
          
          let contentInset: UIEdgeInsets = scrollView.adjustedContentInset
          
          return (scrollView.bounds.width - (contentInset.right + contentInset.left)
           <= scrollView.contentSize.width)
          || (scrollView.bounds.height - (contentInset.top + contentInset.bottom)
              <= scrollView.contentSize.height)
        }
        
        return isScrollable(scrollView: scrollView)
      }
    
    return (scrollView as? UIScrollView)
  }
  
}
