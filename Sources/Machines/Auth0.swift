//
//  File.swift
//  
//
//  Created by Yury Korolev on 26.04.2021.
//

import Promise

public class Auth0 {
  public struct Config {
    public init(clientId: String, domain: String, scope: String, audience: String) {
      self.clientId = clientId
      self.domain = domain
      self.scope = scope
      self.audience = audience
    }
    
    let clientId: String
    let domain: String
    let scope: String
    let audience: String
  }
  
  private let _config: Config
  
  public init(config: Config) {
    _config = config
  }
  
  public func deviceCode() -> Promise<Fetch.JSONOutput, Fetch.Error> {
    RequestResult(
      url: "https://\(_config.domain)/oauth/device/code",
      body: .xWWWFormUrlEncoded([
        "client_id": _config.clientId,
        "scope": _config.scope,
        "audience": _config.audience
      ])
    )
    .fetchJSON(method: .post, expectedStatus: .successfull)
  }
  
  public func activate(deviceCode: String) -> Promise<Fetch.JSONOutput, Fetch.Error> {
    RequestResult(
      url: "https://\(_config.domain)/oauth/token",
      body: .xWWWFormUrlEncoded([
        "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
        "device_code": deviceCode,
        "client_id": _config.clientId,
      ])
    )
    .fetchJSON(method: .post, expectedStatus: .successfull)
  }
  
  public func accessToken(refreshToken: String) -> Promise<Fetch.JSONOutput, Fetch.Error> {
    RequestResult(
      url: "https://\(_config.domain)/oauth/token",
      body: .xWWWFormUrlEncoded([
        "grant_type": "refresh_token",
        "refresh_token": refreshToken,
        "client_id": _config.clientId,
      ])
    )
    .fetchJSON(method: .post, expectedStatus: .successfull)
  }
}

