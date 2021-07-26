
import Foundation
import ArgumentParser
import Machines
import NonStdIO
import Promise
import Darwin

struct DeviceCommands: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "device",
    abstract: "Display commands for authentication of this device",
    shouldDisplay: false,
    subcommands: [
      Authenticate.self,
      Deauthenticate.self,
      Token.self,
    ]
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  struct Authenticate: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Authenticate this device"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      guard
        let deviceCodeResponse = try BuildCLIConfig.shared.auth0.deviceCode().awaitOutput()
      else {
        return
      }
      
      guard
        let deviceCode = deviceCodeResponse.json["device_code"] as? String,
        let verificationURIComplete = deviceCodeResponse.json["verification_uri_complete"] as? String
      else {
        return
      }
     
      print("Please authorize device here:")
      print(verificationURIComplete)
      if let url = URL(string: verificationURIComplete),
        let openURL = BuildCLIConfig.shared.openURL {
        sleep(1)
        print("We are opening that link in the the browser for you.")
        sleep(3)
        openURL(url)
      }
      
      var tries = 8;
      
      try Promise
        .just(deviceCode)
        .delay(.seconds(10))
        .flatMap(BuildCLIConfig.shared.auth0.activate)
        .repeatIfNeeded({ result in
          switch result.fetchError {
          case .unexpectedResponseStatus(let output) where output.response.statusCode == 403:
            tries -= 1
            return tries > 0
          default: return false
          }
        })
        .spinner(io: io, message: "Waiting for authorization")
        .map { $0.json }
        .map(BuildCLIConfig.shared.tokenProvider.saveToken(json:))
        .awaitOutput()
      
      print("Device is authenticated")
    }
  }
  
  struct Deauthenticate: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Deauthenticate this device"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      BuildCLIConfig.shared.tokenProvider.deleteToken()
      print("Token removed")
    }
  }
  
  struct Token: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Display current access token"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      print(BuildCLIConfig.shared.tokenProvider.accessToken ?? "No token")
    }
  }
}
