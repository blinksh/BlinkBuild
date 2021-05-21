//
//  File.swift
//  
//
//  Created by Yury Korolev on 23.04.2021.
//

import Foundation
import Machines
import Promise
import SwiftCLI

fileprivate let url = "https://api-staging.blink.build";

fileprivate let auth0 = Auth0(config: .init(
  clientId: "x7RQ8NR862VscbotFSfu2VO7PEj55ExK",
  domain: "dev-i8bp-l6b.us.auth0.com",
  scope: "offline_access+openid+profile+read:build+write:build",
  audience: "blink.build"
))

fileprivate let tokenProvider = FileAuthTokenProvider(auth0: auth0)


fileprivate func machine() -> Machines.Machine {
  Machines.machine(baseURL: url, auth: .bearer(tokenProvider))
}

fileprivate func containers() -> Machines.Containers {
  machine().containers
}

class StatusCommand: Command {
  
  let name = "status"
  let shortDescription = "Request status for the current user machine"
  
  func execute() {
    machine()
      .status()
      .executeIn(
        cmd: self,
        progressMessage: "Requesting status",
        onSuccess: { output in debugPrint(output) }
      )
  }
}

class AddSSHKeyCommand: Command {
  
  let name = "add-ssh-keys"
  let shortDescription = "Request status for the current user machine"
  
  func execute() {
    machine()
      .status()
      .executeIn(
        cmd: self,
        progressMessage: "Requesting status",
        onSuccess: { output in debugPrint(output) }
      )
  }
}


class StartCommand: Command {
  
  let name = "start"
  let shortDescription = "Start a blink machine"
  
  @Param(validation: .allowing("fra1")) var region: String
  @Param(validation: .allowing("s-1vcpu-2gb")) var size: String
  
  
  func execute() {
    machine()
      .start(region: region, size: size)
      .executeIn(
        cmd: self,
        progressMessage: "Requesting create",
        onSuccess: { output in debugPrint(output) }
      )
  }
}

class StopCommand: Command {
  
  let name = "stop"
  let shortDescription = "Stop a running Blink machine"
  
  func execute() {
    machine()
      .stop()
      .executeIn(
        cmd: self,
        progressMessage: "Requesting stop",
        successMessage: "Machine is stopped."
      )
  }
}

class IPCommand: Command {
  
  let name = "ip"
  let shortDescription = "Request IP address of the current user machine"
  
  func execute() {
    machine()
      .ip()
      .executeIn(
        cmd: self,
        progressMessage: "Requesting IP",
        onSuccess: { stdout <<< $0 }
      )
  }
}


class ContainerCreateCommand: Command {
  
  let name = "create"
  let shortDescription = "Create a new docker container"
  
  @Param var container_name: String
  @Param var image: String
  
  func execute() throws {
    let stdout = self.stdout
    
    try containers()
      .start(name: container_name, image: image)
      .spinner(stdout: stdout, message: "creating container")
      .onMachineNotStarted {
        stdout <<< "Machine is not started."
        let doStart = Input.readBool(prompt: "Start machine?", defaultValue: true, secure: false)
        if !doStart {
          return .just(false)
        }
        return machine()
          .start(region: "fra1", size: "s-1vcpu-2gb").map { _ in return true }
          .delay(.seconds(3)) // wait a little bit to start
          .spinner(stdout: stdout, message: "Starting machine")
      }.awaitOutput()!
    
  
//      .executeIn(
//        cmd: self,
//        progressMessage: "Requesting container/create \(container_name)",
//        successMessage: "\(container_name) is created."
//      )
  }
}

class ContainerRebootCommand: Command {
  
  let name = "reboot"
  let shortDescription = "Reboot a container SSH service"
  
  @Param var container_name: String
  
  func execute() {
    containers()
      .reboot(name: container_name)
      .executeIn(
        cmd: self,
        progressMessage: "Requesting container/reboot for \(container_name)"
      )
  }
  
}

class ContainerStopCommand: Command {
  
  let name = "stop"
  let shortDescription = "Stop a container"
  
  @Param var container_name: String
  
  func execute() {
    containers()
      .stop(name: container_name)
      .executeIn(
        cmd: self,
        progressMessage: "Requesting container/stop for \(container_name)",
        successMessage: "\(container_name) is stopped."
      )
  }
}

class ContainerRemoveCommand: Command {
  
  let name = "remove"
  let shortDescription = "Remove a container"
  
  @Param var container_name: String
  
  func execute() {
    containers()
      .remove(name: container_name)
      .executeIn(
        cmd: self,
        progressMessage: "Requesting container/remove for \(container_name)",
        successMessage: "\(container_name) is removed."
      )
  }
}

class ContainerSaveCommand: Command {
  
  let name = "save"
  let shortDescription = "Save a container state"
  
  @Param var container_name: String
  
  func execute() {
    containers()
      .save(name: container_name)
      .executeIn(
        cmd: self,
        progressMessage: "Requesting container/remove for \(container_name)",
        successMessage: "\(container_name) is saved."
      )
  }
}

class ContainerListCommand: Command {
  
  let name = "list"
  let shortDescription = "List spawned containers"
  
  func execute() {
    containers()
      .list()
      .executeIn(
        cmd: self,
        progressMessage: "Requesting spawned containers",
        onSuccess: { stdout <<< String(describing: $0) }
      )
  }
}

class ContainerAddSSHCommand: Command {
  
  let name = "add-ssh-key"
  let shortDescription = "Add an SSH key to access containers"
  
  @Param var key: String
  
  func execute() {
    machine().sshKeys
      .add(sshKey: key)
      .executeIn(
        cmd: self,
        progressMessage: "Requesting container/add-ssh-key",
        successMessage: "SSH key is added."
      )
  }
}

class ContainerTokenCommand: Command {
  
  let name = "token"
  let shortDescription = "Request an SSH token"
  
  func execute() {
    containers()
      .token()
      .executeIn(
        cmd: self,
        progressMessage: "Requesting container/token",
        onSuccess: { output in
          debugPrint(output)
        }
      )
  }
}

class AuthenticateDevice: Command {
  
  let name = "authenticate-device"
  let shortDescription = "Request an auth0 authentication device code"
  
  func execute() throws {
    guard
      let deviceCodeResponse = try auth0.deviceCode().awaitOutput()
    else {
      return
    }
    
    guard
      let deviceCode = deviceCodeResponse.json["device_code"] as? String,
      let verificationURIComplete = deviceCodeResponse.json["verification_uri_complete"] as? String
    else {
      return
    }
    
    stdout <<< "Please authorize device here:"
    stdout <<< verificationURIComplete
    
    var tries = 3;
    
    try Promise
      .just(deviceCode)
      .delay(.seconds(5))
      .flatMap(auth0.activate)
      .repeatIfNeeded({ result in
        switch result.fetchError {
        case .unexpectedResponseStatus(let output) where output.response.statusCode == 403:
          tries -= 1
          return tries > 0
        default: return false
        }
      })
      .spinner(stdout: stdout, message: "Waiting for authorization", quiet: self.quiet)
      .map { $0.json }
      .map(tokenProvider.saveToken(json:))
      .awaitOutput()
  }
  
}

class ContainerGroup: CommandGroup {
  
  let name = "container"
  let shortDescription = "Container related commands"
  
  let children : [Routable] = [
    ContainerCreateCommand(),
    ContainerRebootCommand(),
    ContainerStopCommand(),
    ContainerRemoveCommand(),
    ContainerSaveCommand(),
    ContainerListCommand(),
    ContainerAddSSHCommand(),
    ContainerTokenCommand()
  ]
  let aliases: [String: String] = [:]
}

private let verboseFlag = Flag("-v", description: "Increase verbosity of informational output")
private let quietFlag = Flag("-q", description: "Decrease verbosity of informational output")

extension Command {
  var verbose: Bool {
    return verboseFlag.value
  }
  
  var quiet: Bool {
    return quietFlag.value
  }
}

let cli = CLI(
  name: "Blink Machines CLI",
  version: "1.0.0",
  description: "Find greatness on Blink cloud",
  commands: [
    AuthenticateDevice(),
    StatusCommand(),
    StartCommand(),
    StopCommand(),
    IPCommand(),
    ContainerGroup()
  ]
)

cli.globalOptions = [
  verboseFlag,
  quietFlag
]

cli.goAndExit()

