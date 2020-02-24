//
//  QiToastView.swift
//  QiToastView
//
//  Created by liusiqi on 2020/1/11.
//  Copyright © 2020 liusiqi. All rights reserved.
//

import UIKit

/*
 * QiToast是一款简单、轻量级、易于使用的弹窗控件。
 
 * 调用”makeToast“方法可以创建一个新视图，并作为toast显示在屏幕上。
 * 调用”showToast“方法可以将任何View作为toast显示在屏幕。
 **/
public extension UIView {
    
    // 用于关联对象的Key
    private struct QiToastKeys {
        static var timer        = "com.qishare.toast.timer"
        static var duration     = "com.qishare.toast.duration"
        static var point        = "com.qishare.toast.point"
        static var completion   = "com.qishare.toast.completion"
        static var activeToasts = "com.qishare.toast.activeToasts"
        static var activityView = "com.qishare.toast.activityView"
        static var queue        = "com.qishare.toast.queue"
    }
    
    /*
     * Swift闭包不能通过Objective-C运行时直接与对象关联。
     * 因此解决方案是将它们封装在一个可以与关联对象一起使用的类中。
     */
    private class QiToastCompletionWrapper {
        let completion: ((Bool) -> Void)?
        
        init(_ completion: ((Bool) -> Void)?) {
            self.completion = completion
        }
    }
    
    private enum QiToastError: Error {
        case missingParameters
    }
    
    // 弹窗数组
    private var QiActiveToasts: NSMutableArray {
        get {
            if let activeToasts = objc_getAssociatedObject(self, &QiToastKeys.activeToasts) as? NSMutableArray {
                return activeToasts
            } else {
                let activeToasts = NSMutableArray()
                objc_setAssociatedObject(self, &QiToastKeys.activeToasts, activeToasts, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return activeToasts
            }
        }
    }
    
    // 弹窗队列
    private var QiQueue: NSMutableArray {
        get {
            if let queue = objc_getAssociatedObject(self, &QiToastKeys.queue) as? NSMutableArray {
                return queue
            } else {
                let queue = NSMutableArray()
                objc_setAssociatedObject(self, &QiToastKeys.queue, queue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return queue
            }
        }
    }
    
    
    // MARK: - Make Toast Methods
    
    func makeToast(_ message: String?, duration: TimeInterval = QiToastManager.shared.duration, position: QiToastPosition = QiToastManager.shared.position, title: String? = nil, image: UIImage? = nil, style: QiToastStyle = QiToastManager.shared.style, completion: ((_ didTap: Bool) -> Void)? = nil) {
        do {
            let toast = try toastViewForMessage(message, title: title, image: image, style: style)
            showToast(toast, duration: duration, position: position, completion: completion)
        } catch QiToastError.missingParameters {
            print("Error: message, title, and image are all nil")
        } catch {}
    }
    
    func makeToast(_ message: String?, duration: TimeInterval = QiToastManager.shared.duration, point: CGPoint, title: String?, image: UIImage?, style: QiToastStyle = QiToastManager.shared.style, completion: ((_ didTap: Bool) -> Void)?) {
        do {
            let toast = try toastViewForMessage(message, title: title, image: image, style: style)
            showToast(toast, duration: duration, point: point, completion: completion)
        } catch QiToastError.missingParameters {
            print("Error: message, title, and image cannot all be nil")
        } catch {}
    }
    
    func showToast(_ toast: UIView, duration: TimeInterval = QiToastManager.shared.duration, position: QiToastPosition = QiToastManager.shared.position, completion: ((_ didTap: Bool) -> Void)? = nil) {
        let point = position.centerPoint(forToast: toast, inSuperview: self)
        showToast(toast, duration: duration, point: point, completion: completion)
    }
    
    func showToast(_ toast: UIView, duration: TimeInterval = QiToastManager.shared.duration, point: CGPoint, completion: ((_ didTap: Bool) -> Void)? = nil) {
        objc_setAssociatedObject(toast, &QiToastKeys.completion, QiToastCompletionWrapper(completion), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        if QiToastManager.shared.isQueueEnabled, QiActiveToasts.count > 0 {
            objc_setAssociatedObject(toast, &QiToastKeys.duration, NSNumber(value: duration), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(toast, &QiToastKeys.point, NSValue(cgPoint: point), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            QiQueue.add(toast)
        } else {
            showToast(toast, duration: duration, point: point)
        }
    }
    
    
    // MARK: - Hide Toast Methods
    
    func hideToast() {
        guard let activeToast = QiActiveToasts.firstObject as? UIView else { return }
        hideToast(activeToast)
    }
    
    func hideToast(_ toast: UIView) {
        guard QiActiveToasts.contains(toast) else { return }
        hideToast(toast, fromTap: false)
    }
    
    func hideAllToasts(includeActivity: Bool = false, clearQueue: Bool = true) {
        if clearQueue {
            clearToastQueue()
        }
        
        QiActiveToasts.compactMap { $0 as? UIView }
                    .forEach { hideToast($0) }
        
        if includeActivity {
            hideLoadingToast()
        }
    }
    
    func clearToastQueue() {
        QiQueue.removeAllObjects()
    }
    
    
    // MARK: - Activity Methods
    
    func showLoadingToast(_ position: QiToastPosition = .center) {
        // sanity
        guard objc_getAssociatedObject(self, &QiToastKeys.activityView) as? UIView == nil else { return }
        
        let toast = createToastActivityView()
        let point = position.centerPoint(forToast: toast, inSuperview: self)
        showLoadingToast(toast, point: point)
    }
    
    func showLoadingToast(_ point: CGPoint) {
        // sanity
        guard objc_getAssociatedObject(self, &QiToastKeys.activityView) as? UIView == nil else { return }
        
        let toast = createToastActivityView()
        showLoadingToast(toast, point: point)
    }
    
    func hideLoadingToast() {
        if let toast = objc_getAssociatedObject(self, &QiToastKeys.activityView) as? UIView {
            UIView.animate(withDuration: QiToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
                toast.alpha = 0.0
            }) { _ in
                toast.removeFromSuperview()
                objc_setAssociatedObject(self, &QiToastKeys.activityView, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    
    // MARK: - Private Activity Methods
    
    private func showLoadingToast(_ toast: UIView, point: CGPoint) {
        toast.alpha = 0.0
        toast.center = point
        
        objc_setAssociatedObject(self, &QiToastKeys.activityView, toast, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        self.addSubview(toast)
        
        UIView.animate(withDuration: QiToastManager.shared.style.fadeDuration, delay: 0.0, options: .curveEaseOut, animations: {
            toast.alpha = 1.0
        })
    }
    
    private func createToastActivityView() -> UIView {
        let style = QiToastManager.shared.style
        
        let activityView = UIView(frame: CGRect(x: 0.0, y: 0.0, width: style.activitySize.width, height: style.activitySize.height))
        activityView.backgroundColor = style.activityBackgroundColor
        activityView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        activityView.layer.cornerRadius = style.cornerRadius
        
        if style.displayShadow {
            activityView.layer.shadowColor = style.shadowColor.cgColor
            activityView.layer.shadowOpacity = style.shadowOpacity
            activityView.layer.shadowRadius = style.shadowRadius
            activityView.layer.shadowOffset = style.shadowOffset
        }
        
        let activityIndicatorView = UIActivityIndicatorView(style: UIActivityIndicatorView.Style.large)
        activityIndicatorView.center = CGPoint(x: activityView.bounds.size.width / 2.0, y: activityView.bounds.size.height / 2.0)
        activityView.addSubview(activityIndicatorView)
        activityIndicatorView.color = style.activityIndicatorColor
        activityIndicatorView.startAnimating()
        
        return activityView
    }
    
    
    // MARK: - Private Show/Hide Methods
    
    private func showToast(_ toast: UIView, duration: TimeInterval, point: CGPoint) {
        toast.center = point
        toast.alpha = 0.0
        
        if QiToastManager.shared.isTapToDismissEnabled {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(UIView.handleToastTapped(_:)))
            toast.addGestureRecognizer(recognizer)
            toast.isUserInteractionEnabled = true
            toast.isExclusiveTouch = true
        }
        
        QiActiveToasts.add(toast)
        self.addSubview(toast)
        
        UIView.animate(withDuration: QiToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            toast.alpha = 1.0
        }) { _ in
            let timer = Timer(timeInterval: duration, target: self, selector: #selector(UIView.toastTimerDidFinish(_:)), userInfo: toast, repeats: false)
            RunLoop.main.add(timer, forMode: .common)
            objc_setAssociatedObject(toast, &QiToastKeys.timer, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private func hideToast(_ toast: UIView, fromTap: Bool) {
        if let timer = objc_getAssociatedObject(toast, &QiToastKeys.timer) as? Timer {
            timer.invalidate()
        }
        
        UIView.animate(withDuration: QiToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            toast.alpha = 0.0
        }) { _ in
            toast.removeFromSuperview()
            self.QiActiveToasts.remove(toast)
            
            if let wrapper = objc_getAssociatedObject(toast, &QiToastKeys.completion) as? QiToastCompletionWrapper, let completion = wrapper.completion {
                completion(fromTap)
            }
            
            if let nextToast = self.QiQueue.firstObject as? UIView, let duration = objc_getAssociatedObject(nextToast, &QiToastKeys.duration) as? NSNumber, let point = objc_getAssociatedObject(nextToast, &QiToastKeys.point) as? NSValue {
                self.QiQueue.removeObject(at: 0)
                self.showToast(nextToast, duration: duration.doubleValue, point: point.cgPointValue)
            }
        }
    }
    
    
    // MARK: - Events
    
    @objc
    private func handleToastTapped(_ recognizer: UITapGestureRecognizer) {
        guard let toast = recognizer.view else { return }
        hideToast(toast, fromTap: true)
    }
    
    @objc
    private func toastTimerDidFinish(_ timer: Timer) {
        guard let toast = timer.userInfo as? UIView else { return }
        hideToast(toast)
    }
    
    
    // MARK: - Toast Construction
    
    func toastViewForMessage(_ message: String?, title: String?, image: UIImage?, style: QiToastStyle) throws -> UIView {
          // sanity
          guard message != nil || title != nil || image != nil else {
              throw QiToastError.missingParameters
          }
          
          var messageLabel: UILabel?
          var titleLabel: UILabel?
          var imageView: UIImageView?
          
          let wrapperView = UIView()
          wrapperView.backgroundColor = style.backgroundColor
          wrapperView.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
          wrapperView.layer.cornerRadius = style.cornerRadius
          
          if style.displayShadow {
              wrapperView.layer.shadowColor = UIColor.black.cgColor
              wrapperView.layer.shadowOpacity = style.shadowOpacity
              wrapperView.layer.shadowRadius = style.shadowRadius
              wrapperView.layer.shadowOffset = style.shadowOffset
          }
          
          if let image = image {
              imageView = UIImageView(image: image)
              imageView?.contentMode = .scaleAspectFit
              imageView?.frame = CGRect(x: style.horizontalPadding, y: style.verticalPadding, width: style.imageSize.width, height: style.imageSize.height)
          }
          
          var imageRect = CGRect.zero
          
          if let imageView = imageView {
              imageRect.origin.x = style.horizontalPadding
              imageRect.origin.y = style.verticalPadding
              imageRect.size.width = imageView.bounds.size.width
              imageRect.size.height = imageView.bounds.size.height
          }

          if let title = title {
              titleLabel = UILabel()
              titleLabel?.numberOfLines = style.titleNumberOfLines
              titleLabel?.font = style.titleFont
              titleLabel?.textAlignment = style.titleAlignment
              titleLabel?.lineBreakMode = .byTruncatingTail
              titleLabel?.textColor = style.titleColor
              titleLabel?.backgroundColor = UIColor.clear
              titleLabel?.text = title;
              
              let maxTitleSize = CGSize(width: (self.bounds.size.width * style.maxWidthPercentage) - imageRect.size.width, height: self.bounds.size.height * style.maxHeightPercentage)
              let titleSize = titleLabel?.sizeThatFits(maxTitleSize)
              if let titleSize = titleSize {
                  titleLabel?.frame = CGRect(x: 0.0, y: 0.0, width: titleSize.width, height: titleSize.height)
              }
          }
          
          if let message = message {
              messageLabel = UILabel()
              messageLabel?.text = message
              messageLabel?.numberOfLines = style.messageNumberOfLines
              messageLabel?.font = style.messageFont
              messageLabel?.textAlignment = style.messageAlignment
              messageLabel?.lineBreakMode = .byTruncatingTail;
              messageLabel?.textColor = style.messageColor
              messageLabel?.backgroundColor = UIColor.clear
              
              let maxMessageSize = CGSize(width: (self.bounds.size.width * style.maxWidthPercentage) - imageRect.size.width, height: self.bounds.size.height * style.maxHeightPercentage)
              let messageSize = messageLabel?.sizeThatFits(maxMessageSize)
              if let messageSize = messageSize {
                  let actualWidth = min(messageSize.width, maxMessageSize.width)
                  let actualHeight = min(messageSize.height, maxMessageSize.height)
                  messageLabel?.frame = CGRect(x: 0.0, y: 0.0, width: actualWidth, height: actualHeight)
              }
          }
    
          var titleRect = CGRect.zero
          
          if let titleLabel = titleLabel {
              titleRect.origin.x = imageRect.origin.x + imageRect.size.width + style.horizontalPadding
              titleRect.origin.y = style.verticalPadding
              titleRect.size.width = titleLabel.bounds.size.width
              titleRect.size.height = titleLabel.bounds.size.height
          }
          
          var messageRect = CGRect.zero
          
          if let messageLabel = messageLabel {
              messageRect.origin.x = imageRect.origin.x + imageRect.size.width + style.horizontalPadding
              messageRect.origin.y = titleRect.origin.y + titleRect.size.height + style.verticalPadding
              messageRect.size.width = messageLabel.bounds.size.width
              messageRect.size.height = messageLabel.bounds.size.height
          }
          
          let longerWidth = max(titleRect.size.width, messageRect.size.width)
          let longerX = max(titleRect.origin.x, messageRect.origin.x)
          let wrapperWidth = max((imageRect.size.width + (style.horizontalPadding * 2.0)), (longerX + longerWidth + style.horizontalPadding))
          let wrapperHeight = max((messageRect.origin.y + messageRect.size.height + style.verticalPadding), (imageRect.size.height + (style.verticalPadding * 2.0)))
          
          wrapperView.frame = CGRect(x: 0.0, y: 0.0, width: wrapperWidth, height: wrapperHeight)
          
          if let titleLabel = titleLabel {
              titleRect.size.width = longerWidth
              titleLabel.frame = titleRect
              wrapperView.addSubview(titleLabel)
          }
          
          if let messageLabel = messageLabel {
              messageRect.size.width = longerWidth
              messageLabel.frame = messageRect
              wrapperView.addSubview(messageLabel)
          }
          
          if let imageView = imageView {
              wrapperView.addSubview(imageView)
          }
          
          return wrapperView
      }
}


// MARK: - QiToastPosition

public enum QiToastPosition {
    case top
    case center
    case bottom
    
    fileprivate func centerPoint(forToast toast: UIView, inSuperview superview: UIView) -> CGPoint {
        let topPadding: CGFloat = QiToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.top
        let bottomPadding: CGFloat = QiToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.bottom
        
        switch self {
        case .top:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: (toast.frame.size.height / 2.0) + topPadding)
        case .center:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: superview.bounds.size.height / 2.0)
        case .bottom:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: (superview.bounds.size.height - (toast.frame.size.height / 2.0)) - bottomPadding)
        }
    }
}


// MARK: - Private UIView Extensions

private extension UIView {
    
    var csSafeAreaInsets: UIEdgeInsets {
        if #available(iOS 11.0, *) {
            return self.safeAreaInsets
        } else {
            return .zero
        }
    }
}

