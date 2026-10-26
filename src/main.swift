// Physical pointer activity claims control. Keyboard claiming is opt-in (keys=N).
// 只看 IOHID 物理设备；Deskflow 用 CGEventPost 注入的事件不经过 IOHID，不会触发。
// 逐个设备 IOHIDDeviceOpen（不 seize），被别人独占（如 Karabiner 抢了内建键盘）的跳过。
// 参数（都放 plist 里调，改参数不用重新编译 → 输入监控授权不失效）：
//   builtin|external   监听内建设备 / 外接 USB+蓝牙设备
//   karabiner          额外把 Karabiner VirtualHIDKeyboard 当键盘源（它只转发物理键盘，CGEvent 注入不经过它）
//   keys=N             keyboard takeover threshold; 0 disables it (default)
//   ptr=N              0.5s 内指针/触控板报告数阈值（默认 6）
//   diag=S             启动后 S 秒内每 2s 打印各设备报告数（默认 0）
//   touch=N            builtin 模式下 0.5s 内内建触控板触摸帧阈值（默认 25，≈0.25s 持续触摸）
// 内建触控板在 Apple Silicon 上不走 HID 鼠标接口，改用 MultitouchSupport 读物理触摸帧。
import Foundation
import IOKit.hid

var productFilter = ""
var mode = "external", useKarabiner = false, minEvents = 6, diagSec = 0.0, minTouch = 25, minKeys = 0
for a in CommandLine.arguments.dropFirst() {
  if a.hasPrefix("product=") { productFilter = String(a.dropFirst(8)) }
  else if a == "builtin" || a == "external" { mode = a }
  else if a == "karabiner" { useKarabiner = true }
  else if a.hasPrefix("keys="), let n = Int(a.dropFirst(5)) { minKeys = n }
  else if a.hasPrefix("ptr="), let n = Int(a.dropFirst(4)) { minEvents = n }
  else if a.hasPrefix("diag="), let n = Double(a.dropFirst(5)) { diagSec = n }
  else if a.hasPrefix("touch="), let n = Int(a.dropFirst(6)) { minTouch = n }
}
let home = FileManager.default.homeDirectoryForCurrentUser.path
let kvmDir = ProcessInfo.processInfo.environment["DUO_STATE_DIR"] ?? "\(home)/Library/Application Support/DeskflowDuo"
let flag = "\(kvmDir)/follower"
let takeControl = "\(kvmDir)/take-control.sh"
let windowSec = 0.5, settleSec = 3.0, cooldownSec = 3.0
let started = Date().timeIntervalSince1970

func log(_ s: String) {
  let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
  print("\(f.string(from: Date())) \(s)"); fflush(stdout)
}
func prop(_ d: IOHIDDevice, _ k: String) -> Any? { IOHIDDeviceGetProperty(d, k as CFString) }
func isKarabinerKeyboard(_ d: IOHIDDevice) -> Bool {
  ((prop(d, kIOHIDProductKey) as? String) ?? "").hasPrefix("Karabiner DriverKit VirtualHIDKeyboard")
}
func accept(_ d: IOHIDDevice) -> Bool {
  let builtIn = (prop(d, "Built-In") as? NSNumber)?.boolValue ?? false
  let transport = (prop(d, kIOHIDTransportKey) as? String) ?? ""
  let product = (prop(d, kIOHIDProductKey) as? String) ?? ""
  if !productFilter.isEmpty && !product.localizedCaseInsensitiveContains(productFilter) { return false }
  if mode == "builtin" && useKarabiner && isKarabinerKeyboard(d) { return true }
  if product.localizedCaseInsensitiveContains("virtual") { return false }
  if mode == "builtin" { return builtIn && ["FIFO", "SPI", "I2C"].contains(transport) }
  return !builtIn && ["USB", "Bluetooth", "Bluetooth Low Energy"].contains(transport)
}
func label(_ d: IOHIDDevice) -> String {
  let p = (prop(d, kIOHIDProductKey) as? String) ?? "?"
  let t = (prop(d, kIOHIDTransportKey) as? String) ?? "?"
  let up = (prop(d, kIOHIDPrimaryUsagePageKey) as? NSNumber)?.intValue ?? 0
  let u = (prop(d, kIOHIDPrimaryUsageKey) as? NSNumber)?.intValue ?? 0
  return "\(p) [\(t)] usage \(up):\(u)"
}

var events: [Double] = [], keyDowns: [Double] = [], touches: [Double] = [], lastTake = 0.0
var opened = Set<UInt64>(), counts: [String: Int] = [:]
func now() -> Double { Date().timeIntervalSince1970 }

func maybeTake() {
  let t = now()
  events.removeAll { t - $0 > windowSec }; keyDowns.removeAll { t - $0 > 1.5 }; touches.removeAll { t - $0 > windowSec }
  guard FileManager.default.fileExists(atPath: flag) else { return }  // 已是主控
  if let m = (try? FileManager.default.attributesOfItem(atPath: flag))?[.modificationDate] as? Date,
     t - m.timeIntervalSince1970 < settleSec { return }
  if t - lastTake < cooldownSec { return }
  events.removeAll { t - $0 > windowSec }
  keyDowns.removeAll { t - $0 > 1.5 }
  touches.removeAll { t - $0 > windowSec }
  guard events.count >= minEvents || (minKeys > 0 && keyDowns.count >= minKeys) || touches.count >= minTouch else { return }
  lastTake = t
  log("physical input (\(events.count) reports, \(keyDowns.count) keys, \(touches.count) touch frames) -> take control")
  let p = Process(); p.executableURL = URL(fileURLWithPath: "/bin/sh"); p.arguments = [takeControl, "quiet"]
  try? p.run()
}

let valueCB: IOHIDValueCallback = { ctx, _, _, value in
  let elem = IOHIDValueGetElement(value)
  let dev = IOHIDElementGetDevice(elem)
  let page = IOHIDElementGetUsagePage(elem), usage = IOHIDElementGetUsage(elem)
  let v = IOHIDValueGetIntegerValue(value)
  let t = now()
  if diagSec > 0 && t - started < diagSec { counts[label(dev), default: 0] += 1 }
  if page == UInt32(kHIDPage_KeyboardOrKeypad) {
    guard usage >= 4 && usage <= 0xE7 && v == 1 else { return }   // 真实按键按下
    if minKeys == 0 { return }
    keyDowns.append(t)
  } else if page == UInt32(kHIDPage_GenericDesktop) || page == UInt32(kHIDPage_Button) || page == UInt32(kHIDPage_Digitizer) {
    guard v != 0 else { return }   // 移动/滚动/点击/触摸
    events.append(t)
  } else { return }
  maybeTake()
}

func openDevice(_ dev: IOHIDDevice) {
  var rid: UInt64 = 0; IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(dev), &rid)
  if opened.contains(rid) { return }
  guard accept(dev) else { log("ignore: \(label(dev))"); opened.insert(rid); return }
  let r = IOHIDDeviceOpen(dev, IOOptionBits(kIOHIDOptionsTypeNone))
  opened.insert(rid)
  if r != kIOReturnSuccess { log("skip (open=\(String(format: "0x%08x", r))): \(label(dev))"); return }
  IOHIDDeviceRegisterInputValueCallback(dev, valueCB, nil)
  IOHIDDeviceScheduleWithRunLoop(dev, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
  log("WATCH: \(label(dev))")
}

let access = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
log("mode=\(mode) karabiner=\(useKarabiner) ptr=\(minEvents) input-monitoring=\(access == kIOHIDAccessTypeGranted ? "granted" : access == kIOHIDAccessTypeDenied ? "denied" : "unknown")")
if access != kIOHIDAccessTypeGranted {
  _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
  // 等 the user 在「输入监控」里打开后，由 launchd 重启生效
  DispatchQueue.main.asyncAfter(deadline: .now() + 20) { log("no input-monitoring access yet, restarting"); exit(1) }
}

let mgr = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
let match: [[String: Int]] = [
  [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Mouse],
  [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Pointer],
  [kIOHIDDeviceUsagePageKey: kHIDPage_GenericDesktop, kIOHIDDeviceUsageKey: kHIDUsage_GD_Keyboard],
  [kIOHIDDeviceUsagePageKey: kHIDPage_Digitizer],
]
IOHIDManagerSetDeviceMatchingMultiple(mgr, match as CFArray)
IOHIDManagerRegisterDeviceMatchingCallback(mgr, { _, _, _, dev in openDevice(dev) }, nil)
IOHIDManagerRegisterDeviceRemovalCallback(mgr, { _, _, _, dev in
  var rid: UInt64 = 0; IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(dev), &rid)
  opened.remove(rid)
  IOHIDDeviceClose(dev, IOOptionBits(kIOHIDOptionsTypeNone))
}, nil)
IOHIDManagerScheduleWithRunLoop(mgr, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
if let devs = IOHIDManagerCopyDevices(mgr) as? Set<IOHIDDevice> { devs.forEach(openDevice) }

// ---- 内建触控板：MultitouchSupport（私有框架，dlopen）----
typealias MTCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, Double, Int32) -> Int32
if mode == "builtin", let h = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW),
   let fList = dlsym(h, "MTDeviceCreateList"), let fReg = dlsym(h, "MTRegisterContactFrameCallback"),
   let fStart = dlsym(h, "MTDeviceStart"), let fBuiltIn = dlsym(h, "MTDeviceIsBuiltIn") {
  let createList = unsafeBitCast(fList, to: (@convention(c) () -> Unmanaged<CFArray>?).self)
  let register = unsafeBitCast(fReg, to: (@convention(c) (UnsafeMutableRawPointer?, MTCallback) -> Void).self)
  let start = unsafeBitCast(fStart, to: (@convention(c) (UnsafeMutableRawPointer?, Int32) -> Void).self)
  let isBuiltIn = unsafeBitCast(fBuiltIn, to: (@convention(c) (UnsafeMutableRawPointer?) -> Bool).self)
  let cb: MTCallback = { _, _, n, _, _ in
    if n > 0 {
      DispatchQueue.main.async {
        let t = now()
        if diagSec > 0 && t - started < diagSec { counts["builtin trackpad (multitouch)", default: 0] += 1 }
        touches.append(t); maybeTake()
      }
    }
    return 0
  }
  if let arr = createList()?.takeRetainedValue() as? [AnyObject] {
    for d in arr {
      let ptr = Unmanaged.passUnretained(d).toOpaque()
      guard isBuiltIn(ptr) else { continue }
      register(ptr, cb); start(ptr, 0)
      log("WATCH: builtin trackpad (multitouch)")
    }
  }
}

if mode == "builtin" { log("Multitouch uses a private framework; verify touch-triggered takeover and wake recovery manually") }
if diagSec > 0 {
  Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { t in
    if !counts.isEmpty { log("diag: " + counts.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")); counts.removeAll() }
    if now() - started > diagSec { t.invalidate() }
  }
}
CFRunLoopRun()
