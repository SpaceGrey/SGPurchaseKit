//
//  File.swift
//  SGPurchaseKit
//
//  Created by 王培屹 on 7/4/25.
//

import Foundation
struct PlistModel:Codable{
    struct PlistItem: Codable {
        var id: String
        var display: Bool

        enum CodingKeys: String, CodingKey {
            case id, display
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            display = try container.decodeIfPresent(Bool.self, forKey: .display) ?? true
        }
    }
    var groupName:String
    var items:[PlistItem]
    var stringItems:[String]{
        return items.map(\.id)
    }
    func checkDisplay(of p:SGProduct)->Bool{
        return items.filter{$0.id == p.productId}.first?.display ?? true
    }
}
