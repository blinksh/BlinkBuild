
import ArgumentParser
import Foundation
import Machines
import NonStdIO


struct ContainersCommands: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "containers",
    abstract: "Display commands working with containers",
    subcommands: [
      Start.self,
      Stop.self,
      List.self,
      Remove.self,
      Save.self
    ]
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  struct Start: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Start container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Option(
      name: .shortAndLong,
      help: "publish a container's port(s) to the host."
    )
    var publish: [String] = []
    
    @Option(
      name: .shortAndLong,
      help: "name of the container"
    )
    var name: String
    
    @Option(
      name: .shortAndLong,
      help: "image of container"
    )
    var image: String
    
    func validate() throws {
      try validateContainerNameInBlinkRegistry(name)
      try validatePublishPorts(ports: publish)
    }
    
    func run() throws {
      _ = try machine()
        .containers
        .start(name: name, image: image, ports: publish)
        .spinner(io: io, message: "Starting container", successMessage: "Container is started.")
        .awaitOutput()
    }
  }
  
  struct Stop: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Stops container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Argument()
    var name: String
    
    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      _ = try machine().containers.stop(name: name).awaitOutput()!
      print("Container is stopped")
    }
  }
  
  struct Save: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Saves container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Argument(help: "Name of the container to save")
    var name: String
    
    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      _ = try containers()
        .save(name: name)
        .spinner(
          io: io,
          message: "Saving container",
          successMessage: "Container is saved",
          failureMessage: "Failed to save container"
        )
        .awaitOutput()!
      print("Container", name, "is saved")
    }
  }
  
  struct List: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "List containers"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      let res = try containers().list().awaitOutput()!
      print(try JSONSerialization.prettyJSON(json: res["containers"]))
    }
  }
  
  struct Remove: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Removes container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Argument()
    var name: String
    
    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      _ = try machine().containers.remove(name: name).awaitOutput()!
      print("Container removed")
    }
  }

}
