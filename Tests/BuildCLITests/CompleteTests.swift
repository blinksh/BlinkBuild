import XCTest
@testable import BuildCLI
import ArgumentParser

enum ParsingState {
  case start, command, args, subcommands
}

class CommandCompletionService {
  struct Argument {
    let name: String?
    let short: String?
    let long: String?
    let help: String?
    let flag: Bool
    let option: Bool
    let subcommand: Bool
    
    static func subcommand(name: String, help: String) -> Argument {
      .init(name: name, short: nil, long: nil, help: help, flag: false, option: false, subcommand: true)
    }
  }
  
  struct Record {
    let command: String
    let args: [Argument]
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
          var short: String? = nil
          var long: String? = nil
          
//          print("arg", cleanLine)
          
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
          
          let arg = Argument(
            name: name,
            short: short,
            long: long,
            help: description,
            flag: flag,
            option: option,
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
      debugPrint(CommandCompletionService.build(for: BuildCommands.self).index)
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
