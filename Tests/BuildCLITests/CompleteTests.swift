import XCTest
@testable import BuildCLI
import ArgumentParser

class CommandCompletionService {
  enum ParsingState {
    case start, command, args, subcommands
  }

  struct Argument: CustomStringConvertible {
    let name: String?
    let short: String?
    let long: String?
    let help: String?
    let flag: Bool // no value
    let option: Bool // value
    let argument: Bool // standalone argument
    let subcommand: Bool
    
    var description: String {
      var result: String = ""
      
      if short != nil || long != nil {
        let names = [short, long].filter { $0 != nil }.map { $0! }.joined(separator: ", ")
        result += "(\(names))"
      }
      
      if let desc = help {
        result += "[\(desc)]"
      }
      
      if let name = name {
        if subcommand {
          result = ":\(name):" + result
        } else {
          result += ":\(name):"
        }
      }
      
      return result
    }
    
    static func subcommand(name: String, help: String) -> Argument {
      .init(
        name: name,
        short: nil,
        long: nil,
        help: help,
        flag: false,
        option: false,
        argument: false,
        subcommand: true
      )
    }
  
  }
  
  struct Record: CustomStringConvertible {
    let command: String
    let args: [Argument]
    
    var description: String {
      var result = "`\(command)`:\(args)"
      
      return result
    }
  }
  
  var index: [String: Record] = [:]
  var rootCommandName: String = "help"
  
  static func build(for cmd: ParsableCommand.Type) -> CommandCompletionService {
    let service = CommandCompletionService()
    service.rootCommandName = cmd._commandName

    var state = ParsingState.start
    
    var command: String = ""
    var args: [Argument] = []
    
    cmd.completionScript(for: .zsh).enumerateLines { line, stop in
      switch state {
      case .start:
        let suffix = "() {"
        if line.hasPrefix("_") && line.hasSuffix(suffix) {
          command = String(Array(line)[1..<line.count - suffix.count])
            .replacingOccurrences(of: "_", with: " ")
          args = []
          state = .command
          print("command `\(command)`")
        }
      case .command:
        switch line {
        case "}":
          state = .start
          let record = Record(command: command, args: args)
          service.index[record.command] = record
        case _ where line.hasSuffix("args+=("):
          state = .args
        case _ where line.hasSuffix("subcommands=("):
          state = .subcommands
        case _: break
        }
      case .subcommands:
        switch line {
        case _ where line.hasSuffix(")"):
          state = .command
        case _:
          var cleanLine = line.trimmingCharacters(in: .whitespaces)
          cleanLine.removeLast()
          cleanLine.removeFirst()
          let nameDescription = cleanLine.split(separator: ":", maxSplits: 1)
          guard
            nameDescription.count == 2,
            let name = nameDescription.first,
            let description = nameDescription.last
          else {
            break
          }

          args.append(.subcommand(name: String(name), help: String(description)))
          print("subcommand", name)
        }
      case .args:
        switch line {
        case _ where line.hasSuffix(")"):
          state = .command
        case _ where line.hasSuffix("'(-): :->command'") || line.hasSuffix("'(-)*:: :->arg'"):
          break
        case _:
          var cleanLine = line.trimmingCharacters(in: .whitespaces)
          cleanLine.removeLast()
          cleanLine.removeFirst()
          
          var description: String? = nil
          var name: String? = nil
          var flag: Bool = false
          var option: Bool = false
          var argument: Bool = false
          var short: String? = nil
          var long: String? = nil
          
          
          if let range = cleanLine.range(
              of: #"\[[^\[]+\]"#,
              options: .regularExpression, range: nil, locale: nil) {
            let lb = cleanLine.index(after: range.lowerBound)
            let ub = cleanLine.index(before: range.upperBound)
            description = String(cleanLine[lb..<ub])
          }
          
          if let range = cleanLine.range(
              of: #"^\([^\)]+\)"#,
              options: .regularExpression, range: nil, locale: nil) {
            let lb = cleanLine.index(after: range.lowerBound)
            let ub = cleanLine.index(before: range.upperBound)
            let names = String(cleanLine[lb..<ub]).split(separator: " ", maxSplits: 1).map(String.init)
            
            short = names.first { $0.hasPrefix("-") && $0.count == 2 }
            long = names.first { $0.hasPrefix("--") }
            flag = true
            option = false
          }
          
          if let range = cleanLine.range(
              of: #":[^:]+:$"#,
              options: .regularExpression, range: nil, locale: nil) {
            let lb = cleanLine.index(after: range.lowerBound)
            let ub = cleanLine.index(before: range.upperBound)
            name = String(cleanLine[lb..<ub])
            flag = false
            option = true
          }
          
          if short == nil, long == nil, cleanLine.hasPrefix("-") {
            short = cleanLine
            flag = true
            option = false
          }
          
          if let name = name, cleanLine == ":" + name + ":" {
            argument = true
            flag = false
            option = false
          }
          
          let arg = Argument(
            name: name,
            short: short,
            long: long,
            help: description,
            flag: flag,
            option: option,
            argument: argument,
            subcommand: false
          )
          
          args.append(arg)
        }
      }
    }
    
    return service
  }
}

final class CompleteTests: XCTestCase {
    func testExample() {
      let service = CommandCompletionService.build(for: BuildCommands.self)
      let foo = service.index["build machine stop"]!
      debugPrint(foo)
//      print(service.index)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
