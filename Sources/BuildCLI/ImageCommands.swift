
import ArgumentParser
import Foundation
import Machines
import NonStdIO


struct ImageCommands: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "images",
    abstract: "Build images"
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  @Argument(
    help: "name of the new image"
  )
  var name: String?
  
  @Argument(
    help: "git url"
  )
  var gitURL: String
  
  func validate() throws {
    guard let _ = URL(string: gitURL)
    else {
      throw ValidationError("Invalid git url")
    }
  }
  
  func run() throws {
    let ip = try machine().ip().awaitOutput()!
    let user = BuildCLIConfig.shared.sshUser
    let args = ["", "-c", "ssh -t -A \(verboseOptions.verbose ? "-v" : "") \(user)@\(ip) build-ctl \([name ?? "", gitURL].filter { $0.isEmpty }.joined(separator: " "))"]
    
    printDebug("Executing command \"/bin/sh" + args.joined(separator: " ") + "\"")
    
    let cargs = args.map { strdup($0) } + [nil]
    
    execv("/bin/sh", cargs)
    
    fatalError("exec failed")
  }
}
