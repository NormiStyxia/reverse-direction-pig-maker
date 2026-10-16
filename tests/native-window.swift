import CoreGraphics
import Foundation
let pid=Int(CommandLine.arguments[1])!
for w in CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? [] {
 if (w[kCGWindowOwnerPID as String] as? Int)==pid, let b=w[kCGWindowBounds as String] as? [String:Any], (b["Height"] as? Int ?? 0)>400, (b["Width"] as? Int ?? 0)>600 {
 let row:[String:Any]=["window":w[kCGWindowNumber as String]!,"title":w[kCGWindowName as String] ?? "","bounds":b]
 print(String(data:try! JSONSerialization.data(withJSONObject:row),encoding:.utf8)!)
 }
}
