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
      commandName: "add",
      abstract: "Add ssh key to dev machine authorization keys"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Argument
    var sshKey: String
    
    func run() throws {
      _ = try machine().sshKeys.add(sshKey: sshKey).awaitOutput()!
      print("Key is added")
    }
  }
  
  struct Remove: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      commandName: "remove",
      abstract: "Remove key by line number from authorization keys"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Option(
      name: .shortAndLong,
      help: "Number of ssh key"
    )
    var index: UInt
    
    func run() throws {
      _ = try machine().sshKeys.removeAt(index: index).awaitOutput()!
    }
  }
  
  struct List: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      commandName: "list",
      abstract: "List keys in authorization keys file"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    func run() throws {
      let res = try machine().sshKeys.list().awaitOutput()!
      var idx = 1
      res.enumerateLines { line, _ in
        print("\(idx): \(line)")
        idx += 1
      }
    }
  }
}
