
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
    }
    
    func run() throws {
      _ = try machine().containers.start(name: name, image: image).awaitOutput()
      print("Started")
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
      _ = try containers().save(name: name).awaitOutput()!
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
      let res = try containers().list().awaitOutput()!["containers"]!
      print(try JSONSerialization.prettyJSON(json: res as Any))
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
