//
//  Codable+PPSocketConvertable.swift
//  Exercise
//
//  Created by pengpeng on 2024/2/22.
//

import Foundation

protocol PPSocketConvertable: Codable {
}

extension PPSocketConvertable {

    func pp_convertToDict() -> [String: Any]? {

        var var_dict: [String: Any]?

        do {
            print("init")
            let var_encoder = JSONEncoder()

            let var_data = try var_encoder.encode(self)
            print("model convert to data")

            var_dict = try JSONSerialization.jsonObject(with: var_data, options: .allowFragments) as? [String: Any]

        } catch {
            print(error)
        }

        return var_dict
    }
    
    func pp_convertToJsonData() -> Data? {
        do {
            let encoder = JSONEncoder()
            let var_data = try encoder.encode(self)
            let var_dict = try JSONSerialization.jsonObject(with: var_data, options: .mutableContainers) as Any
            let result_data = try JSONSerialization.data(withJSONObject: var_dict, options: [.withoutEscapingSlashes, .sortedKeys])
            return result_data
        } catch {
            print(error)
        }
        return nil
    }
    
    func pp_convertToString() -> String? {
        guard let jsonData = pp_convertToJsonData() else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
}

extension Array where Element: PPSocketConvertable {
    func pp_convertToDictArray() -> [[String: Any]]? {
        return self.compactMap { $0.pp_convertToDict() }
    }
    
    func pp_convertToJsonData() -> Data? {
        do {
            let encoder = JSONEncoder()
            return try encoder.encode(self)
        } catch {
            print(error)
        }
        return nil
    }
    
    func pp_convertToString() -> String? {
        guard let jsonData = pp_convertToJsonData() else {
            return nil
        }
        return String(data: jsonData, encoding: .utf8)
    }
}
