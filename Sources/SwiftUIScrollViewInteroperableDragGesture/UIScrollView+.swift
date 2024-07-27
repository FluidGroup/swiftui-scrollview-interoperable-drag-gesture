import UIKit

public struct ScrollViewEdge: OptionSet, CustomStringConvertible, Sendable {
  
  public let rawValue: Int
  
  public init(rawValue: Int) {
    self.rawValue = rawValue
  }
  
  public static let top = ScrollViewEdge(rawValue: 1 << 0)
  public static let bottom = ScrollViewEdge(rawValue: 1 << 1)
  public static let left = ScrollViewEdge(rawValue: 1 << 2)
  public static let right = ScrollViewEdge(rawValue: 1 << 3)
  
  public static var all: ScrollViewEdge {
    [.top, .bottom, .left, .right]
  }
  
  public static var vertical: ScrollViewEdge {
    [.top, .bottom]
  }
  
  public static var horizontal: ScrollViewEdge {
    [.left, .right]
  }
  
  public var description: String {
    var result: [String] = []
    if contains(.top) {
      result.append("top")
    }
    if contains(.bottom) {
      result.append("bottom")
    }
    if contains(.left) {
      result.append("left")
    }
    if contains(.right) {
      result.append("right")
    }
    return result.joined(separator: ", ")
  }
}


extension UIScrollView {

  var scrollableEdges: ScrollViewEdge {
    
    var edges: ScrollViewEdge = []
    
    let contentInset: UIEdgeInsets = adjustedContentInset
    
    // Top
    if contentOffset.y > -contentInset.top {
      edges.insert(.top)
    }
    
    // Left
    if contentOffset.x > -contentInset.left {
      edges.insert(.left)
    }
    
    // bottom
    if contentOffset.y + bounds.height < (contentSize.height + contentInset.bottom) {
      edges.insert(.bottom)
    }
    
    // right
    
    if contentOffset.x + bounds.width < (contentSize.width + contentInset.right) {
      edges.insert(.right)
    }
    
    return edges
  }
  
  //  func isScrollingToTop(includiesRubberBanding: Bool) -> Bool {
  //    if includiesRubberBanding {
  //      return contentOffset.y <= -adjustedContentInset.top
  //    } else {
  //      return contentOffset.y == -adjustedContentInset.top
  //    }
  //  }
  
  //  func isScrollingDown() -> Bool {
  //    return contentOffset.y > -adjustedContentInset.top
  //  }
  
  var contentOffsetToResetY: CGPoint {
    let contentInset = self.adjustedContentInset
    var contentOffset = contentOffset
    contentOffset.y = -contentInset.top
    return contentOffset
  }
  
}
