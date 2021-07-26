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
    abstract: "Create, manage and connect to your Build dev environments.",
    
    discussion: """
    If this is your first time running Build on this device, authenticate with:
      `build device authenticate`

    With Build you can create dev environments, as easy as doing:
      `build up ubuntu`

    Build is powered by Docker, so you can pull any image from the registry. If this is your first time connecting from that device, first install an ssh key:
      `build ssh-copy-id -i <key_name>`

    You can connect using ssh and mosh right out of the box:
      `build ssh ubuntu`
      `build mosh ubuntu`
    Once done, you can save changes to your container:
      `build save ubuntu`
    And take it down:
      `build down ubuntu`
    Or power everything off:
      `build down`
    
    
    """,
    
    subcommands: [
      Up.self,
      Down.self,
      Status.self,
      PS.self,
      customSSHCommand ?? SSH.self,
      customMOSHCommand ?? MOSH.self,
      customSSHCopyCommand ?? SSHCopyID.self,
      IP.self,
      MachineCommands.self,
      BalanceCommands.self,
      SSHKeysCommands.self,
      ContainersCommands.self,
      DeviceCommands.self,
      ImageCommands.self
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
        }
        .flatMap({ _ in
          createAndAddBlinkBuildKeyIfNeeded(io: io)
        })
        .awaitOutput()!
    }
  }
  
  public static func createAndAddBlinkBuildKeyIfNeeded(io: NonStdIO) -> Promise<(), Machines.Error> {
    guard let _ = BuildCLIConfig.shared.blinkBuildPubKey()
    else {
      io.print("No blink-build key is found.")
      io.print("Generating new one.")
      BuildCLIConfig.shared.blinkBuildKeyGenerator()
      if let pubKey = BuildCLIConfig.shared.blinkBuildPubKey() {
        io.print("Adding blink-build key to machine.")
        return machine(io: io).sshKeys.add(sshKey: pubKey)
          .map { _ in }
          .tap { io.print("Key is added.")}
      }
      return .just(())
    }
    return .just(())
  }

  struct Down: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "Stops container"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
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
  
  struct IP: NonStdIOCommand {
    static var configuration = CommandConfiguration(
      abstract: "IP of build machine"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io: NonStdIO = .standart
    
    func run() throws {
      print(try machine(io: io).ip().awaitOutput()!)
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
    
    @Option(
      name: .customShort("i"),
      help: "ssh authentication identity name"
    )
    var identity: String = BuildCLIConfig.shared.sshIdentity
    
    @Option(
      name: .customShort("L", allowingJoined: true),
      help: "<localport>:<bind_address>:<remoteport> Specifies that the given port on the local (client) host is to be forwarded to the given host and port on the remote side."
    )
    var localPortForwards: [String] = []
    
    @Option(
      name: .customShort("R", allowingJoined: true),
      help: "port:host:hostport Specifies that the given port on the remote (server) host is to be forwarded to the given host and port on the local side."
    )
    var reversePortForwards: [String] = []
    
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
      let portStr = port == 22 ? "" : " -p \(port)"
      let agentStr = agent ? " -A" : ""
      if identity == "~/.ssh/blink-build" || identity == "blink-build" {
        _ = try BuildCommands.createAndAddBlinkBuildKeyIfNeeded(io: io).awaitOutput()
      }
      let identityStr = " -i \(NSString(string: identity).expandingTildeInPath)"
      let forwardPortsStr = localPortForwards.isEmpty   ? "" : " " + localPortForwards.map { "-L \($0)" }.joined(separator: " ")
      let reversePortsStr = reversePortForwards.isEmpty ? "" : " " + reversePortForwards.map { "-R \($0)" }.joined(separator: " ")
      let verboseStr = verboseOptions.verbose ? " -v" : ""
      let commandStr = command.joined(separator: " ")
      let args = ["", "-c", "ssh -t\(identityStr)\(portStr)\(agentStr)\(forwardPortsStr)\(reversePortsStr)\(verboseStr) \(user)@\(ip) \(containerName) \(commandStr)"]
      
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
    
    @Option(
      name: .customShort("I"),
      help: "ssh authentication identity name"
    )
    var identity: String = BuildCLIConfig.shared.sshIdentity
    
    func validate() throws {
      try validateContainerName(name)
    }
    
    func run() throws {
      let ip = try machine(io: io).ip().awaitOutput()!
      let user = BuildCLIConfig.shared.sshUser
      let port = BuildCLIConfig.shared.sshPort
      if identity == "~/.ssh/blink-build" || identity == "blink-build" {
        _ = try BuildCommands.createAndAddBlinkBuildKeyIfNeeded(io: io).awaitOutput()
      }
      let identity: String = NSString(string: identity).expandingTildeInPath
      let args = ["", "-c", "mosh --ssh=\"ssh -p \(port) -i \(identity)\" \(user)@\(ip) \(name)"]
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
      help: "Idenity file. Default ~/.ssh/blink-build"
    )
    var identity: String = BuildCLIConfig.shared.sshIdentity
  
    func run() throws {
      if identity == "~/.ssh/blink-build" || identity == "blink-build" && BuildCLIConfig.shared.blinkBuildPubKey() == nil {
        _ = try BuildCommands.createAndAddBlinkBuildKeyIfNeeded(io: io).awaitOutput()
        return
      }
      
      var keyPath = ""
      
      let identity = self.identity.trimmingCharacters(in: .whitespacesAndNewlines)
      if !identity.isEmpty {
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
