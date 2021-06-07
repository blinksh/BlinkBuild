import ArgumentParser
import Machines
import NonStdIO
import Foundation
import Promise


func machine() -> Machines.Machine {
  BuildCLIConfig.shared.machine()
}

func containers() -> Machines.Containers {
  machine().containers
}

public struct BuildCommands: NonStdIOCommand {
  public init() {}
  
  public static var configuration = CommandConfiguration(
    commandName: "build",
    abstract: "build is a command line interface for your dev environments",
    subcommands: [
      MachineCommands.self,
      BalanceCommands.self,
      SSHKeysCommands.self,
      ContainersCommands.self,
      DeviceCommands.self,
      Up.self,
      Down.self,
      PS.self,
      customSSHCommand ?? SSH.self,
      customMOSHCommand ?? MOSH.self,
      customSSHCopyCommand ?? SSHCopyID.self
    ]
  )
  
  public static var customSSHCommand: ParsableCommand.Type? = nil
  public static var customSSHCopyCommand: ParsableCommand.Type? = nil
  public static var customMOSHCommand: ParsableCommand.Type? = nil
  
  
  @OptionGroup public var verboseOptions: VerboseOptions
  public var io = NonStdIO.standart
  
  struct Up: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Starts container and machine if needed"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    @Option(
      name: [.customShort("p", allowingJoined: true), .long],
      help: "publish a container's port(s) to the host."
    )
    var publish: [String] = []
    
    @Option(
      name: [.customShort("i", allowingJoined: true), .long],
      help: "image of container"
    )
    var image: String?
    
    @Argument(
      help: "[blink/]name of the container. Use `blink/` prefix to start saved containers"
    )
    var containerName: String
    
    func validate() throws {
      try validateContainerNameInBlinkRegistry(containerName)
      try validatePublishPorts(ports: publish)
    }
    
    func run() throws {
      _ = try machine().containers
        .start(name: containerName, image: image ?? containerName, ports: publish)
        .spinner(io: io, message: "Creating container", successMessage: "Container is created.")
        .onMachineNotStarted {
          machine()
            .start()
            .map { _ in return true }
            .delay(.seconds(3)) // wait a little bit to start
            .spinner(io: io, message: "Starting machine")
        }.awaitOutput()!
    }
  }

  struct Down: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Stops container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    @Flag(
      name: .shortAndLong,
      help: "Skip machine stop if no containers left"
    )
    var skipMachineAutoStop: Bool = false
    
    @Argument(
      help: "Name of the container"
    )
    var containerName: String
    
    func validate() throws {
      try validateContainerName(containerName)
    }
    
    func run() throws {
      _ = try machine()
        .containers
        .stop(name: containerName)
        .spinner(
          io: io,
          message: "Stopping container `\(containerName)`",
          successMessage: "Container is stopped",
          failureMessage: "Failed to stop container"
        )
        .flatMap({ _ -> Promise<Void, Machines.Error> in
          if skipMachineAutoStop {
            return .just(())
          }
          return machine()
            .containers
            .list()
            .flatMap { json in
            guard
              let containers = json["containers"] as? [[String: Any]],
              containers.isEmpty
            else {
              return .just(())
            }
 
            return machine()
              .stop()
              .spinner(
                io: io,
                message: "No running containers left. Stopping machine...",
                successMessage: "Machine is stopped",
                failureMessage: "Failed to stop machine"
              ).map { _ in }
          }
        })
        .awaitOutput()!
    }
  }
  
  
  struct PS: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "List running containers"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    func run() throws {
      let res = try containers()
        .list()
        .awaitOutput()!
      
      print(try JSONSerialization.prettyJSON(json: res["containers"]))
    }
  }


  struct SSH: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "SSH to container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Flag(
      name: .customShort("A"),
      help: "Enables forwarding of the authentication agent connection"
    )
    var agent: Bool = false
    
    @Argument(
      help: "name of the container"
    )
    var containerName: String
    
    @Argument(
      parsing: .unconditionalRemaining,
      help: .init(
        "If a <command> is specified, it is executed on the container instead of a login shell",
        valueName: "command"
      )
    )
    fileprivate var cmd: [String] = []
    
    var command: [String] {
      get {
        if cmd.first == "--" {
          return Array(cmd.dropFirst())
        } else {
          return cmd
        }
      }
    }

    func validate() throws {
      try validateContainerName(containerName)
    }
    
    func run() throws {
      let ip = try machine().ip().awaitOutput()!
      let user = BuildCLIConfig.shared.sshUser
      let args = ["", "-c", "ssh -t \(agent ? "-A" : "") \(verboseOptions.verbose ? "-v" : "") \(user)@\(ip) \(containerName) \(command.joined(separator: " "))"]
      
      printDebug("Executing command \"/bin/sh" + args.joined(separator: " ") + "\"")
      
      let cargs = args.map { strdup($0) } + [nil]
      
      execv("/bin/sh", cargs)
      
      fatalError("exec failed")
    }
  }

  struct MOSH: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "MOSH to container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Argument(
      help: "name of the container"
    )
    var name: String
    
    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      let ip = try machine().ip().awaitOutput()!
      let user = BuildCLIConfig.shared.sshUser
      let args = ["", "-c", "mosh \(user)@\(ip) \(name)"]
      let cargs = args.map { strdup($0) } + [nil]
      
      execv("/bin/sh", cargs)
      
      fatalError("exec failed")
    }
  }
  
  struct SSHCopyID: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      commandName: "ssh-copy-id",
      abstract: "Add public key to build machine authorized_keys file"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart
    
    @Option(
      name: .shortAndLong,
      help: "Idenity file"
    )
    var identity: String?
  
    func run() throws {
      var keyPath = ""
      if let identity = identity {
        keyPath = identity.hasSuffix(".pub") ? keyPath : identity + ".pub"
      } else {
        keyPath = "~/.ssh/id_rsa.pub"
      }
      
      let path: String = NSString(string: keyPath).expandingTildeInPath
      
      printDebug("Reading key at path: \(path)")
      
      guard
        let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
        let key = String(data: data, encoding: .utf8)
      else {
        throw ValidationError("Can't read pub key at path: \(path)")
        
      }
      
      let _ = machine().sshKeys.add(sshKey: key).awaitResult()
      print("Key is added.")
    }
  }
}
