//
//  ViewController.swift
//  SpeechRecognitionBrowser
//
//  Created by 甲斐翔也 on 2018/07/04.
//  Copyright © 2018 Kai Shoya. All rights reserved.
//

import UIKit
import WebKit

class ViewController: UIViewController, WKUIDelegate {

    @IBOutlet weak var webView: WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.uiDelegate = self
        
        let request = createUrlRequest(urlString: "https://www.google.com/")
        webView.load(request as URLRequest)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 引数で渡したURLをwebViewにセットできる形に変換する
    private func createUrlRequest(urlString: String) -> URLRequest {
        let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        
        let url = URL(string: encodedUrlString!)
        let request = URLRequest(url: url!)
        return request
    }
}

