//
//  File.swift
//  
//
//  Created by Yury Korolev on 20.05.2021.
//

import Foundation

public struct OutputStream: TextOutputStream {
  let fd: Int32
  let file: UnsafeMutablePointer<FILE>
  
  public init(file: UnsafeMutablePointer<FILE>) {
    self.file = file
    self.fd = fileno(file)
  }
  
  #if os(Linux)
  public func write(_ string: String) {
    Glibc.write(fd, string, string.utf8.count)
  }
  
  public func flush() {
    Glibc.fflush(file)
  }
  
  static var stdout: OutputStream { .init(file: Glibc.stdout) }
  static var stderr: OutputStream { .init(file: Glibc.stderr) }
  
  #else
  
  public func write(_ string: String) {
    Darwin.write(fd, string, string.utf8.count)
  }
  
  public func flush() {
    Darwin.fflush(file)
  }
  
  static var stdout: OutputStream { .init(file: Darwin.stdout) }
  static var stderr: OutputStream { .init(file: Darwin.stderr) }
  
  #endif
}


public class NonStdIO: Codable {
  public var out: OutputStream
  public var err: OutputStream
  
  public var verbose: Bool = false
  public var quiet: Bool = false
  
  public init() {
    self.out = OutputStream.stdout
    self.err = OutputStream.stderr
  }
  
  public required init(from decoder: Decoder) throws {
    self.out = OutputStream.stdout
    self.err = OutputStream.stderr
  }
  
  public func encode(to encoder: Encoder) throws {
  }
  
  public static let standart = NonStdIO()
}

public protocol WithNonStdIO {
  var io: NonStdIO { get }
}

public extension NonStdIO {
  func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    guard !quiet else {
      return
    }
    let s = items.map(String.init(describing:)).joined(separator: separator)
    Swift.print(s, terminator: terminator, to: &out)
  }
  
  func printError(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    Swift.print(s, terminator: terminator, to: &err)
  }
  
  func printDebug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    guard verbose else {
      return
    }
    let s = items.map(String.init(describing:)).joined(separator: separator)
    Swift.print(s, terminator: terminator, to: &out)
  }
}


public extension WithNonStdIO {
  func print(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    io.print(s, terminator: terminator)
  }
  
  func printError(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    io.printError(s, terminator: terminator)
  }
  
  func printDebug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let s = items.map(String.init(describing:)).joined(separator: separator)
    io.printDebug(s, terminator: terminator)
  }
}


