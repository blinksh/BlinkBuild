//
//  File.swift
//  
//
//  Created by Yury Korolev on 17.06.2021.
//
import XCTest
@testable import BuildCLI
import Foundation

final class GitURLTests: XCTestCase {
  func testNotModified() {
    GitURL.fromGithub(url: URL(string:"https://github.com")!)
  }
  
  func testGithub() {
    var url: URL
    url = GitURL.fromGithub(url: URL(string:"https://github.com/blinksh/blink")!)
    XCTAssertEqual(url.absoluteString, "git@github.com:blinksh/blink.git")
    
    url = GitURL.fromGithub(url: URL(string:"https://github.com/blinksh/blink#master:myfolder")!)
    XCTAssertEqual(url.absoluteString, "git@github.com:blinksh/blink.git#master:myfolder")
    
    url = GitURL.fromGithub(url: URL(string:"https://github.com/blinksh/blink.git")!)
    XCTAssertEqual(url.absoluteString, "git@github.com:blinksh/blink.git")
    
    url = GitURL.fromGithub(url: URL(string:"github.com/blinksh/blink")!)
    XCTAssertEqual(url.absoluteString, "git@github.com:blinksh/blink.git")
  }
  
  static var allTests = [
    ("testNotModified", testNotModified),
  ]
}
