//
//  ViewController.swift
//  QiToast
//
//  Created by liusiqi on 2020/1/14.
//  Copyright © 2020 liusiqi. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    private lazy var label: UILabel = {
        let label = UILabel.init(frame: CGRect(x: 0, y: 0, width: 100, height: 36))
        label.center = self.view.center
        label.text = "Hello World"
        label.textAlignment = .center
        label.backgroundColor = .lightGray
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        // MARK: - Normal Toast
        
//        self.view.showToast(label) //!< 实例方法调用
//        self.view.makeToast("Hello World") //!< 实例方法调用
//        UIView.showStaticToast(label) //!< 类方法调用
//        UIView.makeStaticToast("Hello World") //!< 类方法调用
        
        
        
        // MARK: - LoadingToast
        
//        self.view.showLoadingToast() //!< 实例方法调用LoadingToast
//        UIView.showStaticLoadingToast(.center) //!< 类方法调用LoadingToast
        
        
        // 模仿网络请求
//        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
//            self.view.hideLoadingToast() //!< 实例方法调用
//            UIView.hideStaticLoadingToast() //!< 类方法调用
//        }
    }

}

