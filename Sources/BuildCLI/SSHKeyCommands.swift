import ArgumentParser
import NonStdIO

struct SSHKeysCommands: NonStdIOCommand {
  static var configuration = CommandConfiguration(
    commandName: "ssh-keys",
    abstract: "Display commands for managing ssh keys on dev machine",
    subcommands: [
      Add.self,
      Remove.self,
      List.self,
    ]
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  struct Add: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Add ssh key to dev machine authorization keys"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Argument
    var sshKey: String
    
    func run() throws {
      _ = try machine()
        .sshKeys
        .add(sshKey: sshKey)
        .spinner(io: io, message: "Adding key", successMessage: "Key is added.", failureMessage: "Failed to add key")
        .awaitOutput()!
    }
  }
  
  struct Remove: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Remove key by line number from authorization keys"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Option(
      name: [.long, .customShort("n", allowingJoined: true)],
      help: "Number of ssh key"
    )
    var number: UInt
    
    func run() throws {
      _ = try machine()
        .sshKeys
        .removeAt(index: number)
        .spinner(
          io: io,
          message: "Removing key",
          successMessage: "Key is removed",
          failureMessage: "Failed to remove key"
        )
        .awaitOutput()!
    }
  }
  
  struct List: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "List keys in authorization keys file"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      let res = try machine()
        .sshKeys
        .list()
        .spinner(
          io: io,
          message: "Retrieving keys",
          failureMessage: "Failed to retrieve keys")
        .awaitOutput()!
      var idx = 1
      res.enumerateLines { line, _ in
        print("\(idx): \(line)")
        idx += 1
      }
    }
  }
}
