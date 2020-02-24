//
//  QiStaticToastView.swift
//  QiStaticToast
//
//  Created by liusiqi on 2020/1/15.
//  Copyright © 2020 liusiqi. All rights reserved.
//

import UIKit

/*
 * QiStaticToast是一款简单、轻量级、易于使用的弹窗控件。
 
 * 调用“makeStaticToast“方法可以创建一个新视图，并作为StaticToast显示在KeyWindow上。
 * 调用”showStaticToast“方法可以将任何View作为StaticToast显示在KeyWindow上。
 **/
public extension UIView {
    
    // 用于关联对象的Key
    private struct QiStaticToastKeys {
        static var timer              = "com.qishare.StaticToast.timer"
        static var duration           = "com.qishare.StaticToast.duration"
        static var point              = "com.qishare.StaticToast.point"
        static var completion         = "com.qishare.StaticToast.completion"
        static var activeStaticToasts = "com.qishare.StaticToast.activeStaticToasts"
        static var activityView       = "com.qishare.StaticToast.activityView"
        static var queue              = "com.qishare.StaticToast.queue"
    }
    
    /*
     * Swift闭包不能通过Objective-C运行时直接与对象关联。
     * 因此解决方案是将它们封装在一个可以与关联对象一起使用的类中。
     */
    private class QiStaticToastCompletionWrapper {
        let completion: ((Bool) -> Void)?
        
        init(_ completion: ((Bool) -> Void)?) {
            self.completion = completion
        }
    }
    
    private enum QiStaticToastError: Error {
        case missingParameters
    }
    
    // 弹窗数组
    private static var QiActiveStaticToasts: NSMutableArray {
        get {
            if let activeStaticToasts = objc_getAssociatedObject(self, &QiStaticToastKeys.activeStaticToasts) as? NSMutableArray {
                return activeStaticToasts
            } else {
                let activeStaticToasts = NSMutableArray()
                objc_setAssociatedObject(self, &QiStaticToastKeys.activeStaticToasts, activeStaticToasts, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return activeStaticToasts
            }
        }
    }
    
    // 弹窗队列
    private static var QiQueue: NSMutableArray {
        get {
            if let queue = objc_getAssociatedObject(self, &QiStaticToastKeys.queue) as? NSMutableArray {
                return queue
            } else {
                let queue = NSMutableArray()
                objc_setAssociatedObject(self, &QiStaticToastKeys.queue, queue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                return queue
            }
        }
    }
    
    
    // MARK: - Make StaticToast Methods
    
    static func makeStaticToast(_ message: String?, duration: TimeInterval = QiStaticToastManager.shared.duration, position: QiStaticToastPosition = QiStaticToastManager.shared.position, title: String? = nil, image: UIImage? = nil, style: QiStaticToastStyle = QiStaticToastManager.shared.style, completion: ((_ didTap: Bool) -> Void)? = nil) {
        do {
            let StaticToast = try StaticToastViewForMessage(message, title: title, image: image, style: style)
            showStaticToast(StaticToast, duration: duration, position: position, completion: completion)
        } catch QiStaticToastError.missingParameters {
            print("Error: message, title, and image are all nil")
        } catch {}
    }
    
    static func makeStaticToast(_ message: String?, duration: TimeInterval = QiStaticToastManager.shared.duration, point: CGPoint, title: String?, image: UIImage?, style: QiStaticToastStyle = QiStaticToastManager.shared.style, completion: ((_ didTap: Bool) -> Void)?) {
        do {
            let StaticToast = try StaticToastViewForMessage(message, title: title, image: image, style: style)
            showStaticToast(StaticToast, duration: duration, point: point, completion: completion)
        } catch QiStaticToastError.missingParameters {
            print("Error: message, title, and image cannot all be nil")
        } catch {}
    }
    
    static func showStaticToast(_ StaticToast: UIView, duration: TimeInterval = QiStaticToastManager.shared.duration, position: QiStaticToastPosition = QiStaticToastManager.shared.position, completion: ((_ didTap: Bool) -> Void)? = nil) {
        
        if let firstKeyWindow = UIApplication.shared.windows.first {
            let point = position.centerPoint(forStaticToast: StaticToast, inSuperview: firstKeyWindow)
            showStaticToast(StaticToast, duration: duration, point: point, completion: completion)
        }
    }
    
    static func showStaticToast(_ StaticToast: UIView, duration: TimeInterval = QiStaticToastManager.shared.duration, point: CGPoint, completion: ((_ didTap: Bool) -> Void)? = nil) {
        objc_setAssociatedObject(StaticToast, &QiStaticToastKeys.completion, QiStaticToastCompletionWrapper(completion), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        
        if QiStaticToastManager.shared.isQueueEnabled, QiActiveStaticToasts.count > 0 {
            objc_setAssociatedObject(StaticToast, &QiStaticToastKeys.duration, NSNumber(value: duration), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(StaticToast, &QiStaticToastKeys.point, NSValue(cgPoint: point), .OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            
            QiQueue.add(StaticToast)
        } else {
            showStaticToast(StaticToast, duration: duration, point: point)
        }
    }
    
    
    // MARK: - Hide StaticToast Methods
    
    static func hideStaticToast() {
        guard let activeStaticToast = QiActiveStaticToasts.firstObject as? UIView else { return }
        hideStaticToast(activeStaticToast)
    }
    
    static func hideStaticToast(_ StaticToast: UIView) {
        guard QiActiveStaticToasts.contains(StaticToast) else { return }
        hideStaticToast(StaticToast, fromTap: false)
    }
    
    static func hideAllStaticToasts(includeActivity: Bool = false, clearQueue: Bool = true) {
        if clearQueue {
            clearStaticToastQueue()
        }
        
        QiActiveStaticToasts.compactMap { $0 as? UIView }
            .forEach { hideStaticToast($0) }
        
        if includeActivity {
            hideStaticLoadingToast()
        }
    }
    
    static func clearStaticToastQueue() {
        QiQueue.removeAllObjects()
    }
    
    
    // MARK: - Activity Methods
    
    static func showStaticLoadingToast(_ position: QiStaticToastPosition = .center) {
        // sanity
        guard objc_getAssociatedObject(self, &QiStaticToastKeys.activityView) as? UIView == nil else { return }
        
        if let firstKeyWindow = UIApplication.shared.windows.first {
            let StaticToast = createStaticToastActivityView()
            let point = position.centerPoint(forStaticToast: StaticToast, inSuperview: firstKeyWindow)
            showStaticLoadingToast(StaticToast, point: point)
        }
    }
    
    static func showStaticLoadingToast(_ point: CGPoint) {
        // sanity
        guard objc_getAssociatedObject(self, &QiStaticToastKeys.activityView) as? UIView == nil else { return }
        
        let StaticToast = createStaticToastActivityView()
        showStaticLoadingToast(StaticToast, point: point)
    }
    
    static func hideStaticLoadingToast() {
        if let StaticToast = objc_getAssociatedObject(self, &QiStaticToastKeys.activityView) as? UIView {
            UIView.animate(withDuration: QiStaticToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
                StaticToast.alpha = 0.0
            }) { _ in
                StaticToast.removeFromSuperview()
                objc_setAssociatedObject(self, &QiStaticToastKeys.activityView, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    
    // MARK: - Private Activity Methods
    
    private static func showStaticLoadingToast(_ StaticToast: UIView, point: CGPoint) {
        StaticToast.alpha = 0.0
        StaticToast.center = point
        
        objc_setAssociatedObject(self, &QiStaticToastKeys.activityView, StaticToast, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        UIApplication.shared.windows.first?.addSubview(StaticToast)
        
        UIView.animate(withDuration: QiStaticToastManager.shared.style.fadeDuration, delay: 0.0, options: .curveEaseOut, animations: {
            StaticToast.alpha = 1.0
        })
    }
    
    private static func createStaticToastActivityView() -> UIView {
        let style = QiStaticToastManager.shared.style
        
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
    
    private static func showStaticToast(_ StaticToast: UIView, duration: TimeInterval, point: CGPoint) {
        StaticToast.center = point
        StaticToast.alpha = 0.0
        
        if QiStaticToastManager.shared.isTapToDismissEnabled {
            let recognizer = UITapGestureRecognizer(target: self, action: #selector(UIView.handleStaticToastTapped(_:)))
            StaticToast.addGestureRecognizer(recognizer)
            StaticToast.isUserInteractionEnabled = true
            StaticToast.isExclusiveTouch = true
        }
        
        QiActiveStaticToasts.add(StaticToast)
        UIApplication.shared.windows.first?.addSubview(StaticToast)
        
        UIView.animate(withDuration: QiStaticToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseOut, .allowUserInteraction], animations: {
            StaticToast.alpha = 1.0
        }) { _ in
            let timer = Timer(timeInterval: duration, target: self, selector: #selector(UIView.StaticToastTimerDidFinish(_:)), userInfo: StaticToast, repeats: false)
            RunLoop.main.add(timer, forMode: .common)
            objc_setAssociatedObject(StaticToast, &QiStaticToastKeys.timer, timer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
    
    private static func hideStaticToast(_ StaticToast: UIView, fromTap: Bool) {
        if let timer = objc_getAssociatedObject(StaticToast, &QiStaticToastKeys.timer) as? Timer {
            timer.invalidate()
        }
        
        UIView.animate(withDuration: QiStaticToastManager.shared.style.fadeDuration, delay: 0.0, options: [.curveEaseIn, .beginFromCurrentState], animations: {
            StaticToast.alpha = 0.0
        }) { _ in
            StaticToast.removeFromSuperview()
            UIView.QiActiveStaticToasts.remove(StaticToast)
            
            if let wrapper = objc_getAssociatedObject(StaticToast, &QiStaticToastKeys.completion) as? QiStaticToastCompletionWrapper, let completion = wrapper.completion {
                completion(fromTap)
            }
            
            if let nextStaticToast = UIView.QiQueue.firstObject as? UIView, let duration = objc_getAssociatedObject(nextStaticToast, &QiStaticToastKeys.duration) as? NSNumber, let point = objc_getAssociatedObject(nextStaticToast, &QiStaticToastKeys.point) as? NSValue {
                UIView.QiQueue.removeObject(at: 0)
                UIView.showStaticToast(nextStaticToast, duration: duration.doubleValue, point: point.cgPointValue)
            }
        }
    }
    
    
    // MARK: - Events
    
    @objc
    private static func handleStaticToastTapped(_ recognizer: UITapGestureRecognizer) {
        guard let StaticToast = recognizer.view else { return }
        UIView.hideStaticToast(StaticToast, fromTap: true)
    }
    
    @objc
    private static func StaticToastTimerDidFinish(_ timer: Timer) {
        guard let StaticToast = timer.userInfo as? UIView else { return }
        UIView.hideStaticToast(StaticToast)
    }
    
    
    // MARK: - StaticToast Construction
    
    static func StaticToastViewForMessage(_ message: String?, title: String?, image: UIImage?, style: QiStaticToastStyle) throws -> UIView {
        // sanity
        guard message != nil || title != nil || image != nil else {
            throw QiStaticToastError.missingParameters
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
            
            let maxTitleSize = CGSize(width: ((UIApplication.shared.windows.first?.bounds.size.width)! * style.maxWidthPercentage) - imageRect.size.width, height: (UIApplication.shared.windows.first?.bounds.size.height)! * style.maxHeightPercentage)
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
            
            if let firstKeyWindow = UIApplication.shared.windows.first {
                let maxMessageSize = CGSize(width: (firstKeyWindow.bounds.size.width * style.maxWidthPercentage) - imageRect.size.width, height: firstKeyWindow.bounds.size.height * style.maxHeightPercentage)
                let messageSize = messageLabel?.sizeThatFits(maxMessageSize)
                if let messageSize = messageSize {
                    let actualWidth = min(messageSize.width, maxMessageSize.width)
                    let actualHeight = min(messageSize.height, maxMessageSize.height)
                    messageLabel?.frame = CGRect(x: 0.0, y: 0.0, width: actualWidth, height: actualHeight)
                }
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


// MARK: - QiStaticToastPosition

public enum QiStaticToastPosition {
    case top
    case center
    case bottom
    
    fileprivate func centerPoint(forStaticToast StaticToast: UIView, inSuperview superview: UIView) -> CGPoint {
        let topPadding: CGFloat = QiStaticToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.top
        let bottomPadding: CGFloat = QiStaticToastManager.shared.style.verticalPadding + superview.csSafeAreaInsets.bottom
        
        switch self {
        case .top:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: (StaticToast.frame.size.height / 2.0) + topPadding)
        case .center:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: superview.bounds.size.height / 2.0)
        case .bottom:
            return CGPoint(x: superview.bounds.size.width / 2.0, y: (superview.bounds.size.height - (StaticToast.frame.size.height / 2.0)) - bottomPadding)
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
