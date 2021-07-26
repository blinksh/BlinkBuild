
import ArgumentParser
import Foundation
import Machines
import NonStdIO


struct ContainersCommands: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "container",
    abstract: "Display commands working with containers",
    shouldDisplay: false,
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
      name: [.customShort("e", allowingJoined: true), .long],
      help: "Set environment variables"
    )
    var env: [String] = []
    
    @Option(
      name: [.customShort("v", allowingJoined: true), .long],
      help: .init("Bind mount a volume", valueName: "source_path:target_path")
    )
    var volume: [String] = []
    
    @Option(
      name: [.customShort("u", allowingJoined: true), .long],
      help: "Username"
    )
    var user: String?
    
    @Option(
      name: [.customShort("p", allowingJoined: true), .long],
      help: "Publish a container's port(s) to the host."
    )
    var publish: [String] = []
    
    @Flag(
      name: [.customShort("P", allowingJoined: true), .long],
      help: "Publish all exposed ports to random ports."
    )
    var publishAll: Bool = false
    
    @Option(
      name: [.customShort("n", allowingJoined: true), .long],
      help: "Name of the container"
    )
    var name: String
    
    @Option(
      name: [.customShort("i", allowingJoined: true), .long],
      help: "Image of container"
    )
    var image: String
    
    func validate() throws {
      try validateContainerNameInBlinkRegistry(name)
      try validatePublishPorts(ports: publish)
      for v in volume {
        try validateVolumeMapping(volume: v)
      }
    }
    
    func run() throws {
      _ = try machine(io: io)
        .containers
        .start(
          name: name,
          image: image,
          ports: publish,
          publishAllPorts: publishAll,
          user: user,
          env: env,
          volume: volume
        )
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
      _ = try machine(io: io).containers.stop(name: name).awaitOutput()!
      print("Container is stopped")
    }
  }
  
  struct Save: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Saves container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Option(
      name: [.customShort("i", allowingJoined: true), .long],
      help: "new image name"
    )
    var image: String?
    
    @Argument(help: "Name of the container to save")
    var containerName: String
    
    func validate() throws {
      try validateContainerName(containerName)
    }
    
    func run() throws {
      _ = try containers(io: io)
        .save(name: containerName, image: image)
        .spinner(
          io: io,
          message: "Saving container",
          successMessage: "Container is saved",
          failureMessage: "Failed to save container"
        )
        .awaitOutput()!
    }
  }
  
  struct List: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "List containers"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Flag(
      name: .shortAndLong,
      help: "Show all containers (default shows just running)"
    )
    var all: Bool = false
    
    func run() throws {
      let res = try containers(io: io).list(all: all).awaitOutput()!
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
      _ = try machine(io: io).containers.remove(name: name).awaitOutput()!
      print("Container removed")
    }
  }

}
