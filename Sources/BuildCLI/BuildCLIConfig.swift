//
//  File.swift
//  
//
//  Created by Yury Korolev on 04.06.2021.
//

import Foundation
import Machines

public class BuildCLIConfig {
  public static var shared: BuildCLIConfig = .init()
  
  public var apiURL = "https://api-staging.blink.build";
  public var auth0: Auth0 = Auth0(config: .init(
    clientId: "x7RQ8NR862VscbotFSfu2VO7PEj55ExK",
    domain: "dev-i8bp-l6b.us.auth0.com",
    scope: "offline_access+openid+profile+read:build+write:build",
    audience: "blink.build"
  ))
  
  public var tokenProvider: AuthTokenProvider
  public var sshUser: String = "blink"
  
  public init(storage: TokenStorage = .file()) {
    tokenProvider = AuthTokenProvider(auth0: auth0, storage: storage)
  }
  
  public func machine() -> Machines.Machine {
    Machines.machine(baseURL: apiURL, auth: .bearer(tokenProvider))
  }
}
