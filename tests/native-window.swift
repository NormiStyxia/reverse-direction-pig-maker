// Read-only lookup restricted to the validation process selected by Python.
import Cocoa
import CoreGraphics
let pid=Int32(CommandLine.arguments[1])!
let rows=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
for row in rows {
    guard row[kCGWindowOwnerPID as String] as? Int32 == pid,
          row[kCGWindowLayer as String] as? Int == 0,
          let bounds=row[kCGWindowBounds as String] as? [String:Any],
          let rect=CGRect(dictionaryRepresentation:bounds as CFDictionary),
          rect.width>600,rect.height>200,
          let id=row[kCGWindowNumber as String] as? Int else {continue}
    let result:[String:Any]=["window":id,"pid":pid,"bounds":bounds,"title":row[kCGWindowName as String] ?? ""]
    let data=try JSONSerialization.data(withJSONObject:result,options:[.sortedKeys])
    print(String(data:data,encoding:.utf8)!)
    break
}
