import Foundation
import ArgumentParser
import NonStdIO
import Machines

struct MachineCommands: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "machine",
    abstract: "Display commands for machine management",
    discussion: "When no files are specified, it expects the source from standard input.",
    subcommands: [
      Start.self,
      Stop.self,
      Status.self,
      IP.self
    ]
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  struct Start: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Starts blink machine",
      discussion: "You have to be authorized first in order to start blink machine."
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Option(
      name: .shortAndLong,
      help: "Region where machine is started. (fra1)")
    var region: String
    
    @Option(
      name: .shortAndLong,
      help: "Size of the machine is started. (s-1vcpu-2gb)")
    var size: String
    
    func validate() throws {
      let regions = Machines.availableRegions
      guard regions.contains(region)
      else {
        throw ValidationError(
          "Invalid `region` value. Possible region values: " + regions.joined(separator: ", ")
        )
      }
      
      let sizes = Machines.availableSizes
      
      guard sizes.contains(size) else {
        throw ValidationError(
          "Invalid `size` value. Possible size values: " + sizes.joined(separator: ", ")
        )
      }
    }
    
    func run() throws {
      _ = try machine().start(region: region, size: size).awaitOutput()!
      print("Machine is started.")
    }
  }
  
  struct Stop: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Stops machine if it is running"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      _ = try machine().stop().awaitOutput()!
      print("Machine is stopped.")
    }
  }
  
  struct Status: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Blink machine management"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      let res = try machine().status().awaitOutput()!
      print(res)
    }
  }
  
  struct IP: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Blink machine ip address"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      let res = try machine().ip().awaitOutput()!
      print(res)
    }
  }
}

public func validateContainerName(_ name: String) throws {
  #if os(Linux)
  #else
  let namePredicate = NSPredicate(
    format:"SELF MATCHES %@",
    Machines.containerNamePattern
  )
  guard namePredicate.evaluate(with: name) else {
    throw ValidationError("Invalid container name: `\(name)`")
  }
  #endif
}




