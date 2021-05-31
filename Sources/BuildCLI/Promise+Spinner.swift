//
//  File.swift
//  
//
//  Created by Yury Korolev on 31.05.2021.
//

import Foundation
import Promise
import Spinner
import NonStdIO

extension Promise {
  func spinner(io: NonStdIO, message: String, successMessage: String? = nil, failureMessage: String? = nil) -> Promise {
    if io.quiet {
      return self
    } else {
      return Promise { fn in
        var s: Spinner? = Spinner(.dots, message, ui: NonStdIOSpinnerUI(io: io))
        s?.start()
        return self.chain { result in
          switch result {
          case .success:
            s?.succeed(successMessage)
          case .failure:
            s?.failure(failureMessage)
          }
          s = nil
          
          fn(result)
        }
        dispose: { s?.stop() }
      }
    }
  }
}
