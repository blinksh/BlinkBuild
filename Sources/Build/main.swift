import Foundation
import NonStdIO
import BuildCLI

let exitCode = BuildCommands.main()

_Exit(exitCode)
