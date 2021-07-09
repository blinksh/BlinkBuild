import NonStdIO
import Promise
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
import NonStdIO
#endif

public enum Machines {
  
  public static var defaultRegion = "fra1"
  public static var defaultSize = "s-1vcpu-2gb"
  
  public static let availableRegions = [defaultRegion, "nyc3", "sfo3"]
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
    let io: NonStdIO
    
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
      
      let request = RequestResult(
        url: baseURL,
        path: command,
        body: .json(args),
        timeoutInterval: timeoutInterval
      )
      
      return request
        .promise().tap({ r in
          if io.verbose {
            io.print("post")
            io.print(" url:", r.url ?? "")
            if let body = r.httpBody, let str = String(data: body, encoding: .utf8) {
              io.print("body:", str)
            }
          }
        }).flatMap { request in
          Fetch.json(
            .post,
            request: request,
            auth: auth,
            session: .shared,
            expectedStatus: expectedStatus
          )
        }
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
      .map { res -> JSON in
        if io.verbose {
          if let response = try? JSONSerialization.prettyJSON(json: res.json) {
            io.print("response:", res.response.statusCode, response)
          } else {
            io.print("response:", res.response)
          }
        }
        return res.json
      }
    }
    
    func subRoute(path: String) -> Client {
      Client(baseURL: baseURL + "/" + path, auth: auth, io: io)
    }
  }
  
  public static func machine(baseURL: String, auth: Fetch.Auth, io: NonStdIO) -> Machine {
    Machine(client: Client(baseURL: baseURL, auth: auth, io: io))
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
    
    public var images: Images {
      Images(client: client.subRoute(path: "image"))
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
  
  public struct Images {
    fileprivate let client: Client
    
    public func list(all: Bool, reference: String?) -> JSONPromise {
      client.run(command: "list", args: reference == nil ? ["all": all] : ["all": all, "reference": reference!])
    }
  }
  
  public struct Containers {
    fileprivate let client: Client
    
    public func start(
      name: String,
      image: String,
      ports: [String] = [],
      publishAllPorts: Bool = false,
      user: String? = nil,
      env: [String] = [],
      volume: [String] = []
    ) -> JSONPromise {
      var args: [String: Any] = [
        "name": name,
        "image": image,
        "ports": ports.map { $0.contains("/") ? $0 : $0 + "/tcp" },
        "publish_all_ports": publishAllPorts,
        "env": __getEnvVars(env: env)
      ]
      if let user = user {
        args["run_as_user"] = user
      }
      args["disk_mount"] = volume.map {
        $0.lowercased().hasPrefix("$build/") ? $0 : "$BUILD/" + $0
      }
      
      return client.run(command: "create", args: args, timeoutInterval: 60 * 3)
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

func __getEnvVars(env:[String]) -> [String] {
  var result = [String]()
  for e in env {
    if e.contains("=") {
      result.append(e)
      continue
    }
    
    if let value = getenv(e) {
      result.append("\(e)=\(String(cString:value))")
    }
  }
  
  return result
}


extension JSONSerialization {
  static func prettyJSON(json: Any?) throws -> String {
    guard
      let data = try? JSONSerialization.data(withJSONObject: json ?? NSNull(), options: .prettyPrinted),
      let string = String(data: data, encoding: .utf8)
    else {
      throw Machines.Error.cannonProcessResponse
    }
    return string
  }
}
