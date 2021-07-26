//
//  File.swift
//  
//
//  Created by Yury Korolev on 04.06.2021.
//

import Foundation
import Machines
import NonStdIO

public class BuildCLIConfig {
  public static var shared: BuildCLIConfig = .init()
  
  public var apiURL = "https://api.blink.build"
  public var auth0: Auth0 = Auth0(config: .init(
    clientId: "x7RQ8NR862VscbotFSfu2VO7PEj55ExK",
    domain: "dev-i8bp-l6b.us.auth0.com",
    scope: "offline_access+openid+profile+read:build+write:build",
    audience: "blink.build"
  ))
  
  public var tokenProvider: AuthTokenProvider
  public var sshUser: String = "blink"
  public var sshPort: Int = 2222
  public var sshIdentity: String = "~/.ssh/blink-build"
  
  public var openURL =  Optional<(URL) -> ()>.none
  public var blinkBuildPubKey:  () -> String? = { nil }
  public var blinkBuildKeyGenerator: () -> () = { }
  
  @TTL public var cachedMachineIP: String? = nil
  
  public func cachedMachineIP(io: NonStdIO) throws -> String {
    try cachedMachineIP ?? machine(io: io).ip().tap({
      self.cachedMachineIP = $0
    }).awaitOutput()!
  }
  
  public init(storage: TokenStorage = .file()) {
    tokenProvider = AuthTokenProvider(auth0: auth0, storage: storage)
    
    #if os(Linux) || os(macOS)
    
    blinkBuildPubKey = {
      let identity: String = NSString(string: self.sshIdentity).expandingTildeInPath
      return try? String(contentsOfFile: identity + ".pub", encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    blinkBuildKeyGenerator = {
      let idenity: String = NSString(string: self.sshIdentity).expandingTildeInPath
      let process = Process()
      process.arguments = ["-t", "ecdsa", "-b", "521" , "-f", idenity, "-N", "", "-C", "blink-build"]
      process.launchPath = "/usr/bin/ssh-keygen"
      process.launch()
      process.waitUntilExit()
    }
    
    #endif
  }
  
  public func machine(io: NonStdIO) -> Machines.Machine {
    Machines.machine(baseURL: apiURL, auth: .bearer(tokenProvider), io: io)
  }
  
  
}


@propertyWrapper public struct TTL<T> {
  private let _ttl: TimeInterval
  private var _updateTime: Date
  private var _val: T? = nil
  
  public var wrappedValue: T? {
    get {
      if _updateTime.timeIntervalSinceNow > _ttl {
        return nil
      }
      return _val
    }
    set {
      _val = newValue
      _updateTime = Date()
    }
  }
  
  public init(ttl: TimeInterval = .init(minutes: 30), wrappedValue: T?) {
    _ttl = ttl
    _updateTime = Date()
    self.wrappedValue = wrappedValue
  }
  
  public mutating func flush() {
    _val = nil
  }
}
