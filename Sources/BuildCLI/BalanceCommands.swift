//
//  File.swift
//  
//
//  Created by Yury Korolev on 20.05.2021.
//

import ArgumentParser
import NonStdIO

struct BalanceCommands: NonStdIOCommand {
  
  static var configuration = CommandConfiguration(
    commandName: "balance",
    abstract: "Display commands for retrieving your account balance",
    discussion: "Note here, that you can turn on/off machine with iOS/iPadOS automation app",
    shouldDisplay: false,
    subcommands: [
      Get.self,
    ]
  )
  
  @OptionGroup var verboseOptions: VerboseOptions
  var io = NonStdIO.standart
  
  struct Get: NonStdIOCommand {
    
    static var configuration = CommandConfiguration(
      abstract: "Retrieve your account balance"
    )
    
    @OptionGroup var verboseOptions: VerboseOptions
    var io = NonStdIO.standart

    func run() {
      print(" ¯ \\_(ツ)_/¯")
    }
  }
}

