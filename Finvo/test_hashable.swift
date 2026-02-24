import SwiftUI

struct Test {
    let a: String = "Test"
    func doSomething() {
        let key = LocalizedStringKey(a)
    }
}
