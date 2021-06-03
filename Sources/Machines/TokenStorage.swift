//
//  File.swift
//  
//
//  Created by Yury Korolev on 24.05.2021.
//

import Foundation

public class TokenStorage {
  public func loadToken() -> [String: Any]? {
    nil
  }
  
  public func saveToken(json: [String: Any]) {
  }
  
  public func deleteToken() {
  }
  
  public static func file(atPath: String = "~/.build.token") -> TokenStorage {
    FileTokenStorage(tokenFilePath: atPath)
  }

  #if os(Linux)
  #else
  public static func userDefaults(_ ud: UserDefaults = .standard, tokenKey: String = "machinesToken") -> TokenStorage {
    UserDefaultsTokenStorage(ud: ud, tokenKey: tokenKey)
  }
  #endif
}

public class FileTokenStorage: TokenStorage {
  private let _tokenFileURL: URL
  
  public init(tokenFilePath: String = "~/.build.token") {
    let path: String = NSString(string: tokenFilePath).expandingTildeInPath
    _tokenFileURL = URL(fileURLWithPath: path)
  }
  
  public override func saveToken(json: [String : Any]) {
    let data = try? JSONSerialization.data(withJSONObject: json, options: [])
    try? data?.write(to: _tokenFileURL)
  }
  
  public override func loadToken() -> [String : Any]? {
    guard
      let data = try? Data(contentsOf: _tokenFileURL, options: []),
      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    else {
      return nil
    }
    return json
  }
  
  public override func deleteToken() {
    try? FileManager.default.removeItem(at: _tokenFileURL)
  }
}

#if os(Linux)
#else

public class UserDefaultsTokenStorage: TokenStorage {
  private let _ud: UserDefaults
  private let _tokenKey: String
  
  public init(ud: UserDefaults, tokenKey: String) {
    _ud = ud
    _tokenKey = tokenKey
  }
  
  public override func loadToken() -> [String : Any]? {
    _ud.dictionary(forKey: _tokenKey)
  }
  
  public override func saveToken(json: [String : Any]) {
    _ud.setValue(json, forKey: _tokenKey)
  }
  
  public override func deleteToken() {
    _ud.removeObject(forKey: _tokenKey)
  }
}

#endif
