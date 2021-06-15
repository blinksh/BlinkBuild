import Promise
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum Machines {
  
  public static var defaultRegion = "fra1"
  public static var defaultSize = "s-1vcpu-2gb"
  
  public static let availableRegions = [defaultRegion, "nyc3", "fra", "nyc"]
  public static let availableSizes = [defaultSize]
  
  public static let containerNamePattern = "^[a-zA-Z0-9][a-zA-Z0-9_.-]+$"
  public static let containerPortMappingPattern
    = "^"                                                     // start of the line
    + "([0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}\\.[0-9]{1,3}:)?" // optional host bind ip
    + "[0-9]{1,5}(:[0-9]{1,5})?"                              // host and optional container ports
    + "(/(tcp)|(udp)|(sctp))?"                                // optional protocol
    + "$"                                                     // end of the line
  
  public enum Error: Swift.Error, LocalizedError {
    case fetchError(Fetch.Error)
    case machineIsNotStarted
    case deviceNotAuthenticated
    case cannonProcessResponse
    
    public var errorDescription: String? {
      switch self {
      case .fetchError(let error): return error.localizedDescription
      case .machineIsNotStarted: return "Machine is not started."
      case .deviceNotAuthenticated: return "This device is not authenticated."
      case .cannonProcessResponse: return "Cannot process response."
      }
    }

    public var recoverySuggestion: String? {
      switch self {
      case .fetchError(let error): return error.recoverySuggestion
      case .machineIsNotStarted: return "Hint: Start machine first with `build machine start` command."
      case .deviceNotAuthenticated: return "Hint: Use `build device authenticate` command first."
      case .cannonProcessResponse: return ""
      }
    }

  }
  
  public typealias JSON = [String: Any]
  public typealias JSONPromise = Promise<JSON, Error>
  
  struct Client {
    let baseURL: String
    let auth: Fetch.Auth
    
    func run(
      command: String,
      args: [String: Any] = [:],
      expectedStatus: Fetch.ResponseStatus = .successfull,
      timeoutInterval: TimeInterval = 60.0
    ) -> JSONPromise {
      
      guard
        case .bearer(let provider) = auth,
        provider.accessToken != nil
      else {
        return .fail(.deviceNotAuthenticated)
      }
      
      return RequestResult(
        url: baseURL,
        path: command,
        body: .json(args),
        timeoutInterval: timeoutInterval
      )
      .fetchJSON(method: .post, auth: auth, expectedStatus: expectedStatus)
      .mapError { err -> Machines.Error in
        switch err {
        case Fetch.Error.unexpectedResponseStatus(let output):
          if output.response.statusCode == 404,
             let json = try? JSONSerialization.jsonObject(with: output.data, options: []) as? [String: Any],
             let message = json["message"] as? String,
             message == "No machine assigned to user. Please run machine create first."  {
            return .machineIsNotStarted
          }
        default: break
        }
        return .fetchError(err)
      }
      .map { $0.json }
    }
    
    func subRoute(path: String) -> Client {
      Client(baseURL: baseURL + "/" + path, auth: auth)
    }
  }
  
  public static func machine(baseURL: String, auth: Fetch.Auth) -> Machine {
    Machine(client: Client(baseURL: baseURL, auth: auth))
  }

  public struct Machine {
    fileprivate let client: Client
    
    public func status() -> Promise<String, Error> {
      client.run(command: "status").stringFor(key: "status")
    }
    
    public func start(region: String = defaultRegion, size: String = defaultSize) -> JSONPromise {
      client.run(command: "create", args: ["region": region, "size": size], timeoutInterval: 60 * 4)
    }
    
    public func stop() -> JSONPromise {
      client.run(command: "stop", timeoutInterval: 60 * 4)
    }
    
    public func ip() -> Promise<String, Error> {
      client.run(command: "ip").stringFor(key: "ip")
    }
    
    public var containers: Containers {
      Containers(client: client.subRoute(path: "container"))
    }
    
    public var sshKeys: SSHKeys {
      SSHKeys(client: client)
    }
  }
  
  public struct SSHKeys {
    fileprivate let client: Client
    
    public func add(sshKey: String) -> JSONPromise {
      var keyParts = sshKey.split(separator: " ").map(String.init)
      if (keyParts.count == 2) {
        keyParts += ["no-comment"]
      }
      return client.run(command: "add-ssh-key", args: ["ssh_key": keyParts.joined(separator: " ")])
    }
    
    public func list() -> Promise<String, Error> {
      client.run(command: "list-ssh-key").stringFor(key: "list_authorized_keys")
    }
    
    public func removeAt(index: UInt) -> JSONPromise {
      client.run(command: "remove-ssh-key", args: ["key_index": index])
    }
  }
  
  public struct Containers {
    fileprivate let client: Client
    
    public func start(name: String, image: String, ports: [String] = []) -> JSONPromise {
      client.run(
        command: "create",
        args: [
          "name": name,
          "image": image,
          "ports": ports.map { $0.contains("/") ? $0 : $0 + "/tcp" }
        ],
        timeoutInterval: 60 * 2
      )
    }
    
    public func reboot(name: String) -> JSONPromise {
      client.run(command: "reboot", args: ["name": name])
    }
    
    public func stop(name: String) -> JSONPromise {
      client.run(command: "stop", args: ["name": name])
    }
    
    public func remove(name: String) -> JSONPromise {
      client.run(command: "remove", args: ["name": name])
    }
    
    public func save(name: String, image: String? = nil) -> JSONPromise {
      client.run(command: "save", args: ["name": name, "image": image ?? NSNull()], timeoutInterval: 60 * 4)
    }
    
    public func list(all: Bool) -> JSONPromise {
      client.run(command: "list", args: ["all": all])
    }
    
    public func token() -> JSONPromise {
      client.run(command: "token")
    }
  }
}

extension Promise where O == Machines.JSON, E == Machines.Error {
  func stringFor(key: String) -> Promise<String, E> {
    self.flatMap { json in
      guard let value = json[key] as? String
      else {
        return .fail(
          .fetchError(
            .unexpectedResponseFormat(name: key, message: "\(key) is missing or not a string")
          )
        )
      }
      
      return .just(value)
    }
  }
  
  public func onMachineNotStarted(fn: @escaping () -> Promise<Bool, Machines.Error> ) -> Promise<O, E> {
    self.flatMapResult { res -> Promise<O, E> in
      switch res {
      case .failure(Machines.Error.machineIsNotStarted):
        return fn().flatMap { restart in restart ?  self : res.promise() }
      default: return res.promise()
      }
    }
  }
}
