import ArgumentParser
import Machines
import NonStdIO
import Foundation
import Promise


func machine(io: NonStdIO) -> Machines.Machine {
  BuildCLIConfig.shared.machine(io: io)
}

func containers(io: NonStdIO) -> Machines.Containers {
  machine(io: io).containers
}

func images(io: NonStdIO) -> Machines.Images {
  machine(io: io).images
}

public struct BuildCommands: NonStdIOCommand {
  public init() {}
  
  public static var configuration = CommandConfiguration(
    commandName: "build",
    abstract: "build is a command line interface for your dev environments",
    subcommands: [
      Up.self,
      Down.self,
      Status.self,
      PS.self,
      MachineCommands.self,
      BalanceCommands.self,
      SSHKeysCommands.self,
      ContainersCommands.self,
      DeviceCommands.self,
      ImageCommands.self,
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
      for v in volume {
        try validateVolumeMapping(volume: v)
      }
    }
    
    func run() throws {
      _ = try machine(io: io).containers
        .start(
          name: containerName,
          image: image ?? containerName,
          ports: publish,
          publishAllPorts: publishAll,
          user: user,
          env: env,
          volume: volume
        )
        .spinner(io: io, message: "Creating container", successMessage: "Container is created.")
        .onMachineNotStarted {
          machine(io: io)
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
    
//    @Flag(
//      name: .shortAndLong,
//      help: "Skip machine stop if no containers left"
//    )
//    var skipMachineAutoStop: Bool = false
    
    @Argument(
      help: "Name of the container"
    )
    var containerName: String?
    
    func validate() throws {
      if let containerName = containerName {
        try validateContainerName(containerName)
      }
    }
    
    func run() throws {
      if let containerName = containerName {
        _ = try machine(io: io)
          .containers
          .stop(name: containerName)
          .spinner(
            io: io,
            message: "Stopping container `\(containerName)`",
            successMessage: "Container is stopped",
            failureMessage: "Failed to stop container"
          )
          .awaitOutput()!
    } else {
      _ = try machine(io: io)
        .containers
        .list(all: false)
        .flatMap { json -> Promise<Void, Machines.Error> in
          if let containers = json["containers"] as? [[String: Any]],
             containers.count > 0 {
            io.print(containers.count, "running", containers.count == 1 ? "container" : "containers")
            io.print("Stop machine anyway? y/N")
            guard
              let anwser = io.in_.readLine()?.lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines),
              ["y", "yes"].contains(anwser)
            else {
              return .just(())
            }
          }
          return machine(io: io)
            .stop()
            .spinner(
              io: io,
              message: "Stopping machine...",
              successMessage: "Machine is stopped",
              failureMessage: "Failed to stop machine"
            ).map { _ in }
        }
        .awaitOutput()!
      }
    }
  }
  
  struct Status: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Status of build machine"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    func run() throws {
      print(try machine(io: io).status().awaitOutput()!)
    }
  }
  
  
  struct PS: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "List running containers"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    @Flag(
      name: .shortAndLong,
      help: "Show all containers (default shows just running)"
    )
    var all: Bool = false
    
    func run() throws {
      let res = try containers(io: io)
        .list(all: all)
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
      let ip = try machine(io: io).ip().awaitOutput()!
      let user = BuildCLIConfig.shared.sshUser
      let port = BuildCLIConfig.shared.sshPort
      let args = ["", "-c", "ssh -p \(port) -t \(agent ? "-A" : "") \(verboseOptions.verbose ? "-v" : "") \(user)@\(ip) \(containerName) \(command.joined(separator: " "))"]
      
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
      let ip = try machine(io: io).ip().awaitOutput()!
      let user = BuildCLIConfig.shared.sshUser
      let port = BuildCLIConfig.shared.sshPort
      let args = ["", "-c", "mosh --ssh=\"ssh -p \(port)\" \(user)@\(ip) \(name)"]
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
        let key = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
      else {
        throw ValidationError("Can't read pub key at path: \(path)")
        
      }
      
      let _ = try machine(io: io).sshKeys.add(sshKey: key).awaitOutput()
      print("Key is added.")
    }
  }
}
