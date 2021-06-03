//
//  File.swift
//  
//
//  Created by Yury Korolev on 03.06.2021.
//

import Foundation
import Machines

extension JSONSerialization {
  static func prettyJSON(json: Any?) throws -> String {
    guard
      let data = try? JSONSerialization.data(withJSONObject: json ?? NSNull(), options: .prettyPrinted),
      let string = String(data: data, encoding: .utf8)
    else {
      throw Machines.Error.cannonProcessResponse
    }
    return string
  }
}
