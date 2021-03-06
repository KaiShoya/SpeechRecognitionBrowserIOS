//
//  ViewController.swift
//  SpeechRecognitionBrowser
//
//  Created by 甲斐翔也 on 2018/07/04.
//  Copyright © 2018 Kai Shoya. All rights reserved.
//
//  Copyright (C) 2016 Apple Inc. All Rights Reserved.
//

import UIKit
import WebKit
import Speech

class ViewController: UIViewController, WKUIDelegate, WKNavigationDelegate, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {

    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var recognitionButton: UIButton!
    
    // 音声認識関連
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // 音声合成関連
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var attributedString: NSMutableAttributedString!
    private var utterance: AVSpeechUtterance!
    
    // 音声認識で単語毎にリセットするために使用
    var timer: Timer?
    
    // 音声認識のstart確認用flg
    var recFlg: Bool = false
    
    // 音声が途切れてから判定処理に入るまでの間隔
    let recognitionInterval = 0.1
    
    // 材料一覧を格納する
    var materials: [[String]] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        webView.uiDelegate = self
        webView.navigationDelegate = self
        
        let request = createUrlRequest(urlString: "https://www.google.com/")
        webView.load(request as URLRequest)
        
        recognitionButton.isEnabled = false
        
        speechSynthesizer.delegate = self
    }
    
    override public func viewDidAppear(_ animated: Bool) {
        speechRecognizer.delegate = self
        
        SFSpeechRecognizer.requestAuthorization { authStatus in
            /*
             The callback may not be called on the main thread. Add an
             operation to the main queue to update the record button's state.
             */
            OperationQueue.main.addOperation {
                switch authStatus {
                case .authorized:
                    self.recognitionButton.isEnabled = true
                    self.recognitionButton.setTitle("音声認識開始", for: [])

                case .denied:
                    self.recognitionButton.isEnabled = false
                    self.recognitionButton.setTitle("音声認識へのアクセスが拒否されました", for: .disabled)
                    
                case .restricted:
                    self.recognitionButton.isEnabled = false
                    self.recognitionButton.setTitle("この端末で音声認識が制限されています", for: .disabled)
                    
                case .notDetermined:
                    self.recognitionButton.isEnabled = false
                    self.recognitionButton.setTitle("音声認識が承認されていません", for: .disabled)
                }
            }
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // 画面遷移開始時
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        // 表示するページがパース対象だったら材料を配列で取得
        guard let urlString = webView.url?.absoluteString else {return}
        if HTMLParser.canBeParsed(urlString: urlString) != HTMLParser.INDEX_NONE {
            materials = HTMLParser.parseMaterial(urlString: urlString)
        } else {
            materials = []
        }
    }
    
    // 引数で渡したURLをwebViewにセットできる形に変換する
    private func createUrlRequest(urlString: String) -> URLRequest {
        let encodedUrlString = urlString.addingPercentEncoding(withAllowedCharacters:NSCharacterSet.urlQueryAllowed)
        
        let url = URL(string: encodedUrlString!)
        let request = URLRequest(url: url!)
        return request
    }
    
    private func startRecording() throws {
        
        // Cancel the previous task if it's running.
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try! audioSession.setCategory(AVAudioSessionCategoryPlayAndRecord, with: .defaultToSpeaker)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        // Configure request so that results are returned before audio recording is finished
        recognitionRequest.shouldReportPartialResults = true
        
        // A recognition task represents a speech recognition session.
        // We keep a reference to the task so that it can be cancelled.
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { result, error in
            var isFinal = false
            
            if let result = result {
                isFinal = result.isFinal
                
                self.timer?.invalidate()
                if self.recFlg {
                    self.timer = Timer.scheduledTimer(withTimeInterval: self.recognitionInterval, repeats: false) {_ in self.recordRestart()}
                }
                
                if isFinal {
                    self.audioEngine.stop()
                    self.recognition(str: result.bestTranscription.formattedString)
                }
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                if !self.recFlg {
                    self.recognitionButton.isEnabled = true
                    self.recognitionButton.setTitle("音声認識開始", for: [])
                } else {
                    try! self.startRecording()
                }
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        
        try audioEngine.start()
    }
    
    // 文字列判定
    private func recognition(str: String) {
        print(str)
        var range: CGFloat = 2.0
        
        if isInclude(str: str, arr: ["もうちょい","餅","もう少し","もうすこし","少し","すこし","ちょっと"]) {
            range = 5.0
        }
        
        if isInclude(str: str, arr: ["上", "うえ"]) {
            pageUp(range: range)
        } else if isInclude(str: str, arr: ["下","した"]) {
            pageDown(range: range)
        } else if isInclude(str: str, arr: ["グラム", "ぐらむ", "どれくらい", "個", "分量", "量は"]) {
            howMuchMaterial(str: str)
        }
    }
    
    // 配列の文字列のどれかが文字列に含まれるかを判定
    private func isInclude(str: String, arr: [String]) -> Bool {
        return arr.contains { text in
            return str.contains(text)
        }
    }
    
    // webViewの表示を上に移動
    private func pageUp(range: CGFloat) {
        webView.scrollView.setContentOffset(CGPoint.init(x: webView.scrollView.contentOffset.x, y: max(webView.scrollView.contentOffset.y - webView.bounds.size.height/range, 0)), animated: true)
    }
    
    // webViewの表示を下に移動
    private func pageDown(range: CGFloat) {
        let maxYOffset = webView.scrollView.contentSize.height - self.webView.scrollView.frame.size.height
        webView.scrollView.setContentOffset(CGPoint.init(x: webView.scrollView.contentOffset.x, y: min(webView.scrollView.contentOffset.y + webView.bounds.size.height/range, maxYOffset)), animated: true)
    }
    
    // 文字列から材料を探し、分量を返す
    private func howMuchMaterial(str: String) {
        
        var text = ""
        for m in materials {
            if isInclude(str: str, arr: [m[0]]) {
                text += m[0] + "は" + m[1] + "です。"
            }
        }
        if text == "" {
            speakText(str: "すみません、よくわかりませんでした。")
        } else {
            speakText(str: text)
        }
    }
    
    // 文字列を喋らせる
    private func speakText(str: String) {
        speechSynthesizer.speak(setSpeechText(text: str))
    }
    
    /// 文字列から音声を合成するための設定
    /// - Parameters:
    ///   - text: 再生したい文字列
    /// - Returns: AVSpeechUtterance
    private func setSpeechText(text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        // 言語を設定
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        // 再生速度を設定
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        // 声の高さを設定
        utterance.pitchMultiplier = 1.0
        
        return utterance
    }
    
    //
    func recordRestart() {
        if audioEngine.isRunning {
//            audioEngine.stop()
            recognitionRequest?.endAudio()
        }
    }
    
    // recognitionButton押下処理
    @IBAction func recognitionButtonOnClicked(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            recognitionRequest?.endAudio()
            recognitionButton.isEnabled = false
            recognitionButton.setTitle("音声認識終了中...", for: .disabled)
            recFlg = false
        } else {
            try! startRecording()
            recognitionButton.setTitle("音声認識終了", for: [])
            recFlg = true
        }
    }
    
    // MARK: SFSpeechRecognizerDelegate
    public func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            if recFlg {
                try! startRecording()
            } else {
                recognitionButton.isEnabled = true
                recognitionButton.setTitle("音声認識開始", for: [])
            }
        } else {
            recognitionButton.isEnabled = false
            recognitionButton.setTitle("音声認識を有効にしてください", for: .disabled)
        }
    }
}

