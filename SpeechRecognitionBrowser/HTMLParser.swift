//
//  HTMLParser.swift
//  SpeechRecognitionBrowser
//
//  Created by 甲斐翔也 on 2018/07/07.
//  Copyright © 2018 Kai Shoya. All rights reserved.
//

import Kanna

struct HTMLParser {
    // インデックス
    static let INDEX_NONE = -1
    static let INDEX_COOKPAD = 0
    static let INDEX_CHEFGOHAN = 1
    
    // ドメイン名
    static let DOMAIN_COOKPAD = "cookpad.com"
    static let DOMAIN_CHEFGOHAN = "chefgohan.gnavi.co.jp"
    
    static func canBeParsed(urlString: String) -> Int {
        if urlString.contains(DOMAIN_COOKPAD+"/recipe/") {
            return INDEX_COOKPAD
        } else if urlString.contains(DOMAIN_CHEFGOHAN+"/detail/") {
            return INDEX_CHEFGOHAN
        }
        return INDEX_NONE
    }
    
    static func parseMaterial(urlString: String) -> [[String]] {
        var arr: [[String]] = []
        let url = URL(string: urlString)
        let data = try? Data(contentsOf: url!)
        if let doc = try? HTML(html: data!, encoding: String.Encoding.utf8) {
            switch(canBeParsed(urlString: urlString)) {
                case INDEX_COOKPAD: arr = parseMaterial4Cookpad(doc: doc)
                case INDEX_CHEFGOHAN: arr = parseMaterial4Chefgohan(doc: doc)
                default: break
            }
        }
        return arr
    }
    
    // cookpadの材料解析
    static func parseMaterial4Cookpad(doc: HTMLDocument) -> [[String]] {
        var arr: [[String]] = []
        for node in doc.css("#ingredients_list > .ingredient_row") {
            guard let name = node.css(".name").first?.text,
                  let amount = node.css(".amount").first?.text else {continue}
            arr.append([name.trimmingCharacters(in: .newlines),
                        amount.trimmingCharacters(in: .newlines)])
        }
        return arr
    }
    
    // シェフごはんの材料解析
    static func parseMaterial4Chefgohan(doc: HTMLDocument) -> [[String]] {
        var arr: [[String]] = []
        for node in doc.css("table.table_recipes > tbody") {
            for data in node.css("tr") {
                var materials: [String] = []
                for td in data.css("td") {
                    guard let str = td.text else {continue}
                    materials.append(str.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                
                if materials.count >= 2 {
                    arr.append(materials)
                }
            }
        }
        return arr
    }
}
