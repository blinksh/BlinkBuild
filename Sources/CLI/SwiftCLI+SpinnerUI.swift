import Spinner
import SwiftCLI
import Promise

struct SwiftCLISpinnerUI: SpinnerUI {
  private let _stdout: WritableStream
  
  init(stdout: WritableStream) {
    _stdout = stdout
  }
  
  func display(string: String) {
    _stdout.write("\r" + string)
  }
  
  func hideCursor() {
    _stdout.write("\u{001B}[?25l")
  }
  
  func unhideCursor() {
    _stdout.write("\u{001B}[?25h")
  }
  
}

extension Promise {
  func spinner(stdout: WritableStream, message: String, quiet: Bool = false) -> Promise {
    if quiet {
      return self
    } else {
      return Promise { fn in
        var s: Spinner? = Spinner(.dots, message, ui: SwiftCLISpinnerUI(stdout: stdout))
        s?.start()
        return self.chain { result in
          switch result {
          case .success:
            s?.succeed()
          case .failure:
            s?.failure()
          }
          s = nil
          fn(result)
        }
        dispose: { s?.stop() }
      }
    }
  }
}

extension Promise {
  func executeIn(cmd: Command, progressMessage: String? = nil, successMessage: String? = nil, onSuccess: (O) -> () = { _ in } ) {
    func verboseMessage(_ message: String) {
      if cmd.verbose {
        cmd.stdout <<< "[verbose] \(message)"
      }
    }
    
    do {
      verboseMessage("executing command: \(cmd.name)")
      
      let output = try self
          .spinner(stdout: cmd.stdout, message: progressMessage ?? "", quiet: cmd.quiet || progressMessage == nil)
          .awaitOutput()!
      
      if let message = successMessage {
        cmd.stdout <<< message
      }
      verboseMessage("success output: " + String(describing: output))
      onSuccess(output)
    } catch {
      verboseMessage("failed with: " + String(describing: error))
      cmd.stderr <<< error.localizedDescription
    }
  }
}
