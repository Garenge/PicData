//
//  String+PPSocketEx.swift
//  GCDSocketDemo
//
//  Created by Garenge on 2025/3/23.
//

import Foundation

extension String {
    
    /// 通用的静态方法，将不同数据类型转换为字符串
    static func pp_stringifi(_ value: Any?) -> String? {
        guard let value = value else {
            return nil
        }
        if let string = value as? String {
            return string
        }
        
        if let data = value as? Data {
            return String(data: data, encoding: .utf8)
        }
        
        if JSONSerialization.isValidJSONObject(value),
           let jsonData = try? JSONSerialization.data(withJSONObject: value, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return nil
    }
}
