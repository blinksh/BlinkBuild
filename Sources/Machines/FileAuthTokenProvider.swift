//
//  File.swift
//  
//
//  Created by Yury Korolev on 30.04.2021.
//

import Foundation
import Promise

public class FileAuthTokenProvider: FetchAuthTokenProvider {
  
  private let _auth0: Auth0
  private var _tokenJSON: [String: Any]? = nil
  private let _tokenFileURL: URL
  
  public init(auth0: Auth0, tokenFilePath: String = "~/.build.token") {
    _auth0 = auth0
    let path: String = NSString(string: tokenFilePath).expandingTildeInPath
    _tokenFileURL = URL(fileURLWithPath: path)
  }
  
  private var tokenJSON: [String: Any]? {
    if let tokenJSON = _tokenJSON {
      return tokenJSON
    }
    _tokenJSON = _loadToken()
    return _tokenJSON
  }
  
  private func _loadToken() -> [String: Any]? {
    guard
      let data = try? Data(contentsOf: _tokenFileURL, options: []),
      let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
    else {
      return nil
    }
    return json
  }
  
  public func saveToken(json: [String: Any]) {
    _tokenJSON = json
    let data = try? JSONSerialization.data(withJSONObject: json, options: [])
    try? data?.write(to: _tokenFileURL)
  }
  
  public func deleteToken() {
    _tokenJSON = nil
    try? FileManager.default.removeItem(at: _tokenFileURL)
  }
  
  public var accessToken: String? {
    tokenJSON?["access_token"] as? String
  }
  
  public var refreshToken: String? {
    tokenJSON?["refresh_token"] as? String
  }
  
  public func refresh() -> Promise<(), Error> {
    guard
      var jsonToken = _tokenJSON,
      let refreshToken = self.refreshToken
    else {
      return .fail(Fetch.Error.cannotBuildUrl)
    }
    
    return _auth0
      .accessToken(refreshToken: refreshToken)
      .map { output -> [String: Any] in
        jsonToken["access_token"] = output.json["access_token"] as? String ?? ""
        jsonToken["token_id"] = output.json["token_id"] as? String ?? ""
        
        return jsonToken
      }
      .map(self.saveToken(json:))
  }
}
