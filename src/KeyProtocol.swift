import CryptoKit
import Foundation

/// Exact key payload: kind + event type + keycode + flags + autorepeat = 13 bytes.
struct KeyStroke: Equatable {
  let eventType: UInt8
  let keyCode: UInt16
  let flags: UInt64
  let autorepeat: UInt8

  var data: Data {
    var d = Data([1, eventType])
    withUnsafeBytes(of: keyCode.bigEndian) { d.append(contentsOf: $0) }
    withUnsafeBytes(of: flags.bigEndian) { d.append(contentsOf: $0) }
    d.append(autorepeat)
    return d
  }
  init(eventType: UInt8, keyCode: UInt16, flags: UInt64, autorepeat: UInt8) {
    self.eventType = eventType
    self.keyCode = keyCode
    self.flags = flags
    self.autorepeat = autorepeat
  }
  init?(_ d: Data) {
    let b = [UInt8](d)
    guard b.count == 13, b[0] == 1, [10, 11, 12].contains(b[1]), b[12] <= 1 else { return nil }
    self.init(
      eventType: b[1], keyCode: UInt16(b[2]) << 8 | UInt16(b[3]),
      flags: b[4..<12].reduce(0) { $0 << 8 | UInt64($1) }, autorepeat: b[12])
  }
}

/// Per-connection nonces bind authenticated frames to both ends of this session.
/// A replayed hello cannot make old data frames valid for a new receiver nonce.
final class KeyWireCodec {
  let key: SymmetricKey
  let nonce: Data
  private(set) var peerNonce: Data?
  private var sendSeq: UInt64 = 0
  private var recvSeq: UInt64 = 0
  static func milliseconds() -> UInt64 { UInt64(Date().timeIntervalSince1970 * 1000) }

  init(key: Data, nonce: Data? = nil) {
    self.key = SymmetricKey(data: key)
    self.nonce = nonce ?? Data((0..<16).map { _ in UInt8.random(in: 0...255) })
  }
  func seal(_ payload: Data, now: UInt64 = KeyWireCodec.milliseconds()) -> Data? {
    let hello = payload == Data([5])
    guard nonce.count == 16, !payload.isEmpty, payload.count <= 128,
      sendSeq < UInt64.max, hello ? sendSeq == 0 : peerNonce != nil
    else { return nil }
    sendSeq += 1
    var p = Data()
    withUnsafeBytes(of: sendSeq.bigEndian) { p.append(contentsOf: $0) }
    withUnsafeBytes(of: now.bigEndian) { p.append(contentsOf: $0) }
    p.append(nonce)
    p.append(hello ? Data(repeating: 0, count: 16) : peerNonce!)
    p.append(payload)
    guard let box = try? ChaChaPoly.seal(p, using: key).combined else { return nil }
    var frame = Data()
    withUnsafeBytes(of: UInt16(box.count).bigEndian) { frame.append(contentsOf: $0) }
    frame.append(box)
    return frame
  }
  func open(_ box: Data, now: UInt64 = KeyWireCodec.milliseconds()) -> Data? {
    guard box.count <= 1024, let sealed = try? ChaChaPoly.SealedBox(combined: box),
      let p = try? ChaChaPoly.open(sealed, using: key), p.count >= 49
    else { return nil }
    let b = [UInt8](p)
    let seq = b[0..<8].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let ms = b[8..<16].reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
    let sender = Data(b[16..<32])
    let target = Data(b[32..<48])
    let payload = Data(b.dropFirst(48))
    guard seq > recvSeq, (now > ms ? now - ms : ms - now) < 10_000 else { return nil }
    if payload == Data([5]) {
      guard recvSeq == 0, peerNonce == nil, seq == 1,
        target == Data(repeating: 0, count: 16)
      else { return nil }
      peerNonce = sender
    } else {
      guard peerNonce == sender, target == nonce else { return nil }
    }
    recvSeq = seq
    return payload
  }
}

// Routing policy is shared by the event tap and standalone acceptance tests.
enum KeyboardRouting {
  static func shouldForward(
    enabled: Bool, emergencyOff: Bool, follower: Bool,
    cursorHere: Bool, authenticatedPeer: Bool
  ) -> Bool {
    enabled && !emergencyOff && follower && !cursorHere && authenticatedPeer
  }
}
