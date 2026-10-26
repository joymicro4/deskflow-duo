import Foundation

@main struct KeyProtocolTests {
  static func main() {
    let key = Data(repeating: 7, count: 32)
    let a = KeyWireCodec(key: key, nonce: Data(repeating: 1, count: 16))
    let b = KeyWireCodec(key: key, nonce: Data(repeating: 2, count: 16))
    let stroke = KeyStroke(eventType: 11, keyCode: 40, flags: 0x100008, autorepeat: 0)
    precondition(stroke.data.count == 13)
    precondition(KeyStroke(stroke.data) == stroke, "13-byte key payload must decode")
    precondition(KeyStroke(Data(stroke.data.dropLast())) == nil)
    precondition(KeyStroke(stroke.data + Data([0])) == nil)
    precondition(KeyStroke(Data([1, 99]) + stroke.data.dropFirst(2)) == nil)
    precondition(a.seal(stroke.data, now: 1000) == nil, "no data before handshake")
    let helloA = a.seal(Data([5]), now: 1000)!
    let helloB = b.seal(Data([5]), now: 1000)!
    precondition(b.open(Data(helloA.dropFirst(2)), now: 1000) == Data([5]))
    precondition(a.open(Data(helloB.dropFirst(2)), now: 1000) == Data([5]))
    let frame = a.seal(stroke.data, now: 1000)!
    precondition(b.open(Data(frame.dropFirst(2)), now: 1000) == stroke.data)
    precondition(b.open(Data(frame.dropFirst(2)), now: 1000) == nil, "reject same-session replay")
    let fresh = KeyWireCodec(key: key, nonce: Data(repeating: 3, count: 16))
    precondition(fresh.open(Data(helloA.dropFirst(2)), now: 1000) == Data([5]))
    precondition(
      fresh.open(Data(frame.dropFirst(2)), now: 1000) == nil, "reject cross-session replay")
    let wrong = KeyWireCodec(key: Data(repeating: 8, count: 32))
    precondition(wrong.open(Data(helloA.dropFirst(2)), now: 1000) == nil)
    let expired = KeyWireCodec(key: key)
    precondition(expired.open(Data(helloA.dropFirst(2)), now: 20000) == nil)
    var corrupt = Data(frame.dropFirst(2))
    corrupt[corrupt.startIndex] ^= 1
    precondition(b.open(corrupt, now: 1000) == nil)
    // Four combinations: local master uses Deskflow; follower forwards only
    // while the cursor is on the other Mac. Roles are symmetric.
    for _ in 0..<2 {
      precondition(
        !KeyboardRouting.shouldForward(
          enabled: true, emergencyOff: false, follower: false, cursorHere: true,
          authenticatedPeer: true))
      precondition(
        KeyboardRouting.shouldForward(
          enabled: true, emergencyOff: false, follower: true, cursorHere: false,
          authenticatedPeer: true))
      precondition(
        !KeyboardRouting.shouldForward(
          enabled: true, emergencyOff: false, follower: true, cursorHere: true,
          authenticatedPeer: true))
    }
    precondition(
      !KeyboardRouting.shouldForward(
        enabled: true, emergencyOff: false, follower: true, cursorHere: false,
        authenticatedPeer: false))
    precondition(
      !KeyboardRouting.shouldForward(
        enabled: true, emergencyOff: true, follower: true, cursorHere: false,
        authenticatedPeer: true))
    print("PASS key payload length/flags, handshake, wrong key, tamper, expiry and replay checks")
  }
}
