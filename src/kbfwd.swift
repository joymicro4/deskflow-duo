import ApplicationServices
import CoreGraphics
import CryptoKit
// 键盘跟着光标走（v0.2）：
// 被控方（follower）的 Deskflow client 处于 leave（光标在主控机上）时，用 CGEventTap 拦下本机物理键盘事件，
// 经加密通道（TCP + ChaChaPoly，预共享密钥 the private state directory/fwd.key）发给主控机，由主控机注入。
// 兜底：通道不通 / 不是 follower / 光标在本机 / 被紧急关闭 → 一律放行本地。⌃⌥⌘K 切换拦截开关（会弹通知）。
// 参数：fwd=listen:PORT | fwd=connect:HOST:PORT    kbfwd=off|observe|on（observe 只统计不拦截）
import Foundation
import Network

var fwdSpec = ""
var kbMode = "off"
var disabledFile: String { "\(kvmDir)/kbfwd-disabled" }
var clientLog: String { "\(kvmDir)/logs/client.log" }

struct Stats {
  var seen = 0, physical = 0, forwarded = 0, sendFail = 0, injected = 0, injectFail = 0,
    rejected = 0, pidNonZero = 0
}
var st = Stats()

// ---------- Authenticated, session-bound channel ----------
var keyData: Data?
var codec: KeyWireCodec?
var conn: NWConnection?
var listener: NWListener?
var lastPong = 0.0
var connectedAt = 0.0
var peerCanInject = false
var channelAlive: Bool { conn?.state == .ready && now() - lastPong < 3 }
var channelUp: Bool { channelAlive && peerCanInject }

func tcpParams() -> NWParameters {
  let tcp = NWProtocolTCP.Options()
  tcp.noDelay = true
  tcp.connectionTimeout = 2
  tcp.enableKeepalive = true
  tcp.keepaliveIdle = 2
  return NWParameters(tls: nil, tcp: tcp)
}
func send(_ plain: Data) -> Bool {
  guard let c = conn, c.state == .ready, let f = codec?.seal(plain) else { return false }
  c.send(
    content: f,
    completion: .contentProcessed { error in
      guard conn === c else { return }
      if error != nil {
        st.sendFail += 1
        closeChannel(c)
      }
    })
  return true
}
func closeChannel(_ c: NWConnection) {
  guard conn === c else {
    c.cancel()
    return
  }
  lastPong = 0
  peerCanInject = false
  releaseInjected()
  fwdDown.removeAll()
  fwdMods.removeAll()
  wasForwarding = false
  conn = nil
  codec = nil
  c.cancel()
  log("fwd channel closed; local keyboard pass-through")
}
func receiveLoop(_ c: NWConnection, _ buf: Data = Data()) {
  c.receive(minimumIncompleteLength: 1, maximumLength: 4096) { d, _, done, error in
    guard conn === c else { return }
    var b = buf
    if let d = d { b.append(d) }
    while b.count >= 2 {
      let n = Int(b[b.startIndex]) << 8 | Int(b[b.startIndex + 1])
      guard n >= 77 && n <= 1024 else {
        st.rejected += 1
        closeChannel(c)
        return
      }
      guard b.count >= 2 + n else { break }
      let box = b.subdata(in: (b.startIndex + 2)..<(b.startIndex + 2 + n))
      b.removeFirst(2 + n)
      guard let m = codec?.open(box) else {
        st.rejected += 1
        closeChannel(c)
        return
      }
      handle(m)
    }
    if done || error != nil {
      closeChannel(c)
      return
    }
    receiveLoop(c, b)
  }
}
func adopt(_ c: NWConnection) {
  guard conn == nil, let key = keyData else {
    c.cancel()
    return
  }
  conn = c
  codec = KeyWireCodec(key: key)
  lastPong = 0
  peerCanInject = false
  c.stateUpdateHandler = { state in
    guard conn === c else { return }
    switch state {
    case .ready:
      connectedAt = now()
      log("fwd transport ready; waiting for authenticated pong")
      _ = send(Data([5]))
    case .failed, .waiting, .cancelled: closeChannel(c)
    default: break
    }
  }
  c.start(queue: .main)
  receiveLoop(c)
}
func startListener(_ port: NWEndpoint.Port) {
  guard listener == nil else { return }
  do {
    let l = try NWListener(using: tcpParams(), on: port)
    listener = l
    l.newConnectionHandler = { c in adopt(c) }
    l.stateUpdateHandler = { state in
      if case .waiting = state {
        l.cancel()
        if listener === l { listener = nil }
      }
      if case .failed = state {
        l.cancel()
        if listener === l { listener = nil }
      }
      if case .cancelled = state { if listener === l { listener = nil } }
    }
    l.start(queue: .main)
  } catch { log("fwd listener unavailable; retrying without changing firewall") }
}
func startChannel() {
  var listenPort: NWEndpoint.Port?
  var connectHost: NWEndpoint.Host?
  var connectPort: NWEndpoint.Port?
  if fwdSpec.hasPrefix("listen:") {
    listenPort = NWEndpoint.Port(String(fwdSpec.dropFirst(7)))
  } else if fwdSpec.hasPrefix("connect:") {
    let spec = String(fwdSpec.dropFirst(8))
    if let split = spec.lastIndex(of: ":") {
      connectHost = NWEndpoint.Host(String(spec[..<split]))
      connectPort = NWEndpoint.Port(String(spec[spec.index(after: split)...]))
    }
  }
  guard listenPort != nil || (connectHost != nil && connectPort != nil) else {
    log("kbfwd invalid channel configuration")
    return
  }
  if let port = listenPort { startListener(port) }
  Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
    if let c = conn, c.state == .ready, now() - connectedAt > 3, now() - lastPong > 3 {
      closeChannel(c)
    }
    if let port = listenPort { startListener(port) }
    if conn == nil, let host = connectHost, let port = connectPort {
      adopt(NWConnection(host: host, port: port, using: tcpParams()))
    }
    _ = send(Data([3]))
    if isFollower || emergencyOff || !channelAlive { releaseInjected() }
  }
}

// ---------- 光标是否在本机（follower 侧：读 Deskflow client 日志的 entering/leaving） ----------
var cursorHere = true
var logOffset: UInt64 = 0
var logRemainder = ""
func pollClientLog() {
  guard let fh = FileHandle(forReadingAtPath: clientLog) else {
    cursorHere = true
    return
  }
  defer { try? fh.close() }
  let end = fh.seekToEndOfFile()
  if end < logOffset {
    logOffset = 0
    logRemainder = ""
    cursorHere = true
  }
  if logOffset == 0 { logOffset = end > 65536 ? end - 65536 : 0 }
  fh.seek(toFileOffset: logOffset)
  let d = fh.readDataToEndOfFile()
  logOffset = end
  guard let s = String(data: d, encoding: .utf8) else { return }
  let text = logRemainder + s
  var lines = text.components(separatedBy: "\n")
  logRemainder = lines.removeLast()
  for line in lines {
    if line.contains("INFO: entering computer") {
      cursorHere = true
    } else if line.contains("INFO: leaving computer") || line.contains("connected to secure socket")
      || line.contains("started client") || line.contains("disconnected from server")
    {
      cursorHere = false
    }
  }
}
var isFollower: Bool { FileManager.default.fileExists(atPath: flag) }
var emergencyOff: Bool { FileManager.default.fileExists(atPath: disabledFile) }
var shouldForward: Bool {
  KeyboardRouting.shouldForward(
    enabled: kbMode == "on", emergencyOff: emergencyOff, follower: isFollower,
    cursorHere: cursorHere, authenticatedPeer: channelUp)
}

// ---------- 拦截（follower） ----------
var fwdDown = Set<UInt16>()
var fwdMods = Set<UInt16>()
var wasForwarding = false
var tap: CFMachPort?
var panicKeyDown = false

func notify(_ msg: String) {
  let p = Process()
  p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
  p.arguments = [
    "-e", "display notification \"\(msg)\" with title \"Deskflow Duo\" subtitle \"⌃⌥⌘K 切换\"",
  ]
  try? p.run()
}
func releaseRemote() {
  if !fwdDown.isEmpty || !fwdMods.isEmpty { _ = send(Data([2])) }
  fwdDown.removeAll()
  fwdMods.removeAll()
}
let tapCB: CGEventTapCallBack = { _, type, ev, _ in
  if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    releaseRemote()
    releaseInjected()
    if let t = tap { CGEvent.tapEnable(tap: t, enable: true) }
    return Unmanaged.passUnretained(ev)
  }
  st.seen += 1
  let pid = ev.getIntegerValueField(.eventSourceUnixProcessID)
  let physical = pid == 0
  if physical { st.physical += 1 } else { st.pidNonZero += 1 }
  let key = UInt16(ev.getIntegerValueField(.keyboardEventKeycode))
  if physical && key == 40 && panicKeyDown {
    if type == .keyUp { panicKeyDown = false }
    return nil
  }
  // 紧急开关：⌃⌥⌘K（物理按键），切换拦截开/关，并弹通知
  if type == .keyDown && key == 40 && physical
    && ev.getIntegerValueField(.keyboardEventAutorepeat) == 0
  {
    let f = ev.flags
    if f.contains(.maskCommand) && f.contains(.maskAlternate) && f.contains(.maskControl)
      && !f.contains(.maskShift)
    {
      panicKeyDown = true
      if emergencyOff {
        try? FileManager.default.removeItem(atPath: disabledFile)
        log("kbfwd re-enabled (ctrl-opt-cmd-K)")
        notify("键盘跟随光标：已开启")
      } else {
        FileManager.default.createFile(atPath: disabledFile, contents: nil)
        releaseRemote()
        releaseInjected()
        log("kbfwd DISABLED (ctrl-opt-cmd-K)")
        notify("键盘跟随光标：已关闭（本机键盘只输入本机）")
      }
      return nil  // 吞掉组合键本身
    }
  }
  let fwd = shouldForward
  if wasForwarding && !fwd { releaseRemote() }
  wasForwarding = fwd
  guard fwd && physical else { return Unmanaged.passUnretained(ev) }
  let stroke = KeyStroke(
    eventType: UInt8(type.rawValue & 0xff), keyCode: key,
    flags: ev.flags.rawValue,
    autorepeat: UInt8(ev.getIntegerValueField(.keyboardEventAutorepeat) & 1))
  guard send(stroke.data) else {
    releaseRemote()
    return Unmanaged.passUnretained(ev)
  }
  if type == .keyDown { fwdDown.insert(key) } else if type == .keyUp { fwdDown.remove(key) }
  if type == .flagsChanged {
    if modKeys[key].map({ ev.flags.contains($0) }) ?? false {
      fwdMods.insert(key)
    } else {
      fwdMods.remove(key)
    }
  }
  st.forwarded += 1
  return nil  // 吞掉，不交给本地 App
}

// ---------- 注入（主控机） ----------
var injDown = Set<UInt16>()
var injMods = Set<UInt16>()
let modKeys: [UInt16: CGEventFlags] = [
  55: .maskCommand, 54: .maskCommand, 56: .maskShift, 60: .maskShift,
  58: .maskAlternate, 61: .maskAlternate, 59: .maskControl, 62: .maskControl, 57: .maskAlphaShift,
  63: .maskSecondaryFn,
]
let injSrc = CGEventSource(stateID: .privateState)

func post(_ key: UInt16, _ down: Bool, _ type: CGEventType, _ flags: CGEventFlags, _ rep: Int64 = 0)
  -> Bool
{
  guard let e = CGEvent(keyboardEventSource: injSrc, virtualKey: key, keyDown: down) else {
    return false
  }
  e.type = type
  e.flags = flags
  if rep != 0 { e.setIntegerValueField(.keyboardEventAutorepeat, value: rep) }
  e.post(tap: .cghidEventTap)
  return true
}
func releaseInjected() {
  for k in injDown { _ = post(k, false, .keyUp, []) }
  for k in injMods { _ = post(k, false, .flagsChanged, []) }
  injDown.removeAll()
  injMods.removeAll()
}
func handle(_ m: Data) {
  let b = [UInt8](m)
  guard let type = b.first else { return }
  switch type {
  case 5 where b.count == 1: _ = send(Data([3]))
  case 3 where b.count == 1:
    let ready: UInt8 =
      AXIsProcessTrusted() && !isFollower && !emergencyOff && kbMode == "on" ? 1 : 0
    _ = send(Data([4, ready]))
  case 4 where b.count == 2:
    if lastPong == 0 { log("fwd authenticated pong received") }
    lastPong = now()
    peerCanInject = b[1] == 1
  case 2 where b.count == 1: releaseInjected()
  case 1:
    guard let stroke = KeyStroke(m), let eventType = CGEventType(rawValue: UInt32(stroke.eventType))
    else {
      st.rejected += 1
      return
    }
    guard kbMode == "on", !emergencyOff, !isFollower, AXIsProcessTrusted() else {
      st.injectFail += 1
      return
    }
    let key = stroke.keyCode
    let flags = CGEventFlags(rawValue: stroke.flags)
    var ok = false
    switch eventType {
    case .keyDown:
      ok = post(key, true, .keyDown, flags, Int64(stroke.autorepeat))
      if ok { injDown.insert(key) }
    case .keyUp:
      guard injDown.contains(key) else { return }
      ok = post(key, false, .keyUp, flags)
      if ok { injDown.remove(key) }
    case .flagsChanged:
      guard let mask = modKeys[key] else {
        st.rejected += 1
        return
      }
      let down = flags.contains(mask)
      ok = post(key, down, .flagsChanged, flags)
      if ok { if down { injMods.insert(key) } else { injMods.remove(key) } }
    default: return
    }
    if ok { st.injected += 1 } else { st.injectFail += 1 }
  default: st.rejected += 1
  }
}

// ---------- 启动 ----------
func startKbFwd() {
  for a in CommandLine.arguments.dropFirst() {
    if a.hasPrefix("fwd=") {
      fwdSpec = String(a.dropFirst(4))
    } else if a.hasPrefix("kbfwd=") {
      kbMode = String(a.dropFirst(6))
    }
  }

  guard kbMode != "off", !fwdSpec.isEmpty else { return }
  let keyPath = "\(kvmDir)/fwd.key"
  guard let key = FileManager.default.contents(atPath: keyPath), key.count == 32,
    let attributes = try? FileManager.default.attributesOfItem(atPath: keyPath),
    (attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600
  else {
    log("kbfwd requires a 32-byte shared key with mode 0600; local pass-through")
    return
  }
  keyData = key
  let trusted = AXIsProcessTrustedWithOptions(
    [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: kbMode == "on"] as CFDictionary)
  log("kbfwd mode=\(kbMode) fwd=\(fwdSpec) accessibility=\(trusted)")
  startChannel()
  Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
    pollClientLog()
    if wasForwarding && !shouldForward {
      releaseRemote()
      wasForwarding = false
    }
  }
  let mask =
    (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
    | (1 << CGEventType.flagsChanged.rawValue)
  let opt: CGEventTapOptions = kbMode == "on" ? .defaultTap : .listenOnly
  tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: opt,
    eventsOfInterest: CGEventMask(mask), callback: tapCB, userInfo: nil)
  if let t = tap {
    CFRunLoopAddSource(
      CFRunLoopGetCurrent(), CFMachPortCreateRunLoopSource(nil, t, 0), .commonModes)
    CGEvent.tapEnable(tap: t, enable: true)
    log("kbfwd tap ok (\(kbMode == "on" ? "intercept" : "listen-only"))")
  } else {
    log("kbfwd tap FAILED (need Accessibility for intercept / Input Monitoring for listen)")
  }
  var last = Stats()
  Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { _ in
    let s = st
    if s.seen != last.seen || s.injected != last.injected || s.rejected != last.rejected
      || s.sendFail != last.sendFail
    {
      log(
        "kbfwd stats: seen=\(s.seen) physical(pid0)=\(s.physical) pidNonZero=\(s.pidNonZero) forwarded=\(s.forwarded) sendFail=\(s.sendFail) injected=\(s.injected) injectFail=\(s.injectFail) rejected=\(s.rejected) channel=\(channelUp) follower=\(isFollower) cursorHere=\(cursorHere)"
      )
      last = s
    }
  }
}
