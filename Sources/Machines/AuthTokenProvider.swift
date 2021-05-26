//
//  File.swift
//  
//
//  Created by Yury Korolev on 30.04.2021.
//

import Foundation
import Promise


public class AuthTokenProvider: FetchAuthTokenProvider {
  private let _auth0: Auth0
  private var _tokenJSON: [String: Any]? = nil
  private var _tokenStorage: TokenStorage
  
  public init(auth0: Auth0, storage: TokenStorage) {
    _auth0 = auth0
    _tokenStorage = storage
  }
  
  private var tokenJSON: [String: Any]? {
    if let tokenJSON = _tokenJSON {
      return tokenJSON
    }
    _tokenJSON = _tokenStorage.loadToken()
    return _tokenJSON
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
      .map(_tokenStorage.saveToken(json:))
  }
  
  public func saveToken(json: [String: Any]) {
    _tokenJSON = json
    _tokenStorage.saveToken(json: json)
  }
  
  public func deleteToken() {
    _tokenJSON = nil
    _tokenStorage.deleteToken()
  }
}
