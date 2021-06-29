import XCTest
@testable import Machines

final class MachinesTests: XCTestCase {
    func testExample() {
      do  {
        guard
          let output = try Machines
            .machine(
              baseURL: "http://yandex.ru",
              auth: .none,
              io: .standart
            )
            .containers.start(name: "test", image: "node")
            .awaitOutput()
        else {
          return debugPrint("canceled")
        }
        
        debugPrint(output)
      } catch {
        debugPrint(error)
      }
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
