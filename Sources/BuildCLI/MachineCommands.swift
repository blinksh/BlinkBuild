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
      help: "Region where machine is started. (fra1)"
//      completion: .list(Machines.availableRegions)
    )
    var region: String = Machines.availableRegions.first!
    
    @Option(
      name: .shortAndLong,
      help: "Size of the machine is started. (s-1vcpu-2gb)"
//      completion: .list(Machines.availableSizes)
    )
    var size: String = Machines.availableSizes.first!
    
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
      _ = try machine(io: io)
        .start(region: region, size: size)
        .spinner(
          io: io,
          message: "Starting machine",
          successMessage: "Machine is started",
          failureMessage: "Failed to start machine"
        )
        .awaitOutput()
    }
  }
  
  struct Stop: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Stops machine if it is running"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      _ = try machine(io: io)
        .stop()
        .spinner(
          io: io,
          message: "Stopping machine",
          successMessage: "Machine is stopped.",
          failureMessage: "Failed to stop machine."
        )
        .awaitOutput()
    }
  }
  
  struct Status: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Build machine status"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      print(try machine(io: io).status().awaitOutput()!)
    }
  }
  
  struct IP: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Blink machine ip address"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      print(try machine(io: io).ip().awaitOutput()!)
    }
  }
}

public func validateContainerName(_ name: String) throws {
  guard let _ = name.range(
          of: Machines.containerNamePattern,
          options: .regularExpression,
          range: nil, locale: nil)
  else {
    throw ValidationError("Invalid container name: `\(name)`")
  }
}

public func validateVolumeMapping(volume: String?) throws {
  guard let volume = volume
  else {
    return
  }
  
  let parts = volume.split(separator: ":").map(String.init)
  guard parts.count == 2
  else {
    throw ValidationError("Invalid volume mapping: `\(volume)`")
  }
  
  if parts[0].lowercased().starts(with: "$build/") {
    if !parts[1].starts(with: "/") {
      throw ValidationError("Invalid volume mapping: `\(volume)`. Paths should be absolute")
    }
    return
  }
  
  guard parts.allSatisfy( { $0.starts(with: "/")} )
  else {
    throw ValidationError("Invalid volume mapping: `\(volume)`. Paths should be absolute")
  }
}

public func validatePublishPorts(ports: [String]) throws {
  for port in ports {
    try validatePublishPortMapping(portMapping: port)
  }
}

public func validatePublishPortMapping(portMapping: String) throws {
  guard let _ = portMapping.range(
          of: Machines.containerPortMappingPattern,
          options: .regularExpression,
          range: nil, locale: nil)
  else {
    throw ValidationError("Invalid port mapping: `\(portMapping)`")
  }
}


public func validateContainerNameInBlinkRegistry(_ name: String) throws {
  let parts = name.split(separator: "/", maxSplits: 1).map(String.init)
  if parts.first == "blink" && parts.count == 2 {
    try validateContainerName(parts.last!)
    return
  }
  
  try validateContainerName(name)
}
