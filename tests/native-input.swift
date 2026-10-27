// Physical macOS event adapter for an explicitly identified test Runtime PID.
import Foundation
import AppKit
import ApplicationServices
let args=CommandLine.arguments
if args.count==2 && args[1]=="trusted" {
    print(CGPreflightPostEventAccess() ? "POST_EVENTS_ALLOWED" : "POST_EVENTS_NOT_ALLOWED")
    exit(0)
}
guard args.count>=4,let pid=Int32(args[1]),let app=NSRunningApplication(processIdentifier:pid),app.executableURL?.lastPathComponent=="UrhoXRuntime" else {
    fputs("Expected the explicitly selected UrhoXRuntime PID\n",stderr);exit(2)
}
guard CGPreflightPostEventAccess() else {fputs("Accessibility event posting is not authorized\n",stderr);exit(3)}
let source=CGEventSource(stateID:.privateState)
if args[2]=="focus" {
    app.unhide();app.activate(options:[.activateIgnoringOtherApps,.activateAllWindows])
    let element=AXUIElementCreateApplication(pid)
    let status=AXUIElementSetAttributeValue(element,kAXFrontmostAttribute as CFString,kCFBooleanTrue)
    print("FOCUS",pid,"AX",status.rawValue)
} else if args[2]=="hide" {
    app.hide();print("HIDE",pid)
} else if args[2]=="key",let key=UInt16(args[3]) {
    guard args.count==5 else {exit(2)}
    let down=args[4]=="down"
    guard down || args[4]=="up" else {exit(2)}
    CGEvent(keyboardEventSource:source,virtualKey:key,keyDown:down)?.postToPid(pid)
    print("KEY",pid,key,down ? "down" : "up")
} else if args[2]=="click",args.count==5,let x=Double(args[3]),let y=Double(args[4]) {
    let point=CGPoint(x:x,y:y)
    let windows=CGWindowListCopyWindowInfo(.optionAll,kCGNullWindowID) as? [[String:Any]] ?? []
    guard let window=windows.first(where:{($0[kCGWindowOwnerPID as String] as? Int32)==pid && ($0[kCGWindowLayer as String] as? Int)==0 && (($0[kCGWindowBounds as String] as? [String:Any])?["Width"] as? Int ?? 0)>600 && (($0[kCGWindowBounds as String] as? [String:Any])?["Height"] as? Int ?? 0)>200}),let windowID=window[kCGWindowNumber as String] as? Int64 else {exit(4)}
    guard NSWorkspace.shared.frontmostApplication?.processIdentifier==pid,
          let bounds=window[kCGWindowBounds as String] as? [String:Any],
          let rect=CGRect(dictionaryRepresentation:bounds as CFDictionary),rect.contains(point) else {
        print("CLICK_REJECTED","frontPID",NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1,"targetPID",pid,"bounds",window[kCGWindowBounds as String] ?? "missing","point",point);exit(5)
    }
    // SDL's mouse backend consumes HID mouse events. Verify the target owns the
    // front window and click position before posting; keys remain PID-targeted.
    let oldPoint=CGEvent(source:nil)?.location
    CGWarpMouseCursorPosition(point)
    for type in [CGEventType.mouseMoved,.leftMouseDown,.leftMouseUp] {
        if let event=CGEvent(mouseEventSource:source,mouseType:type,mouseCursorPosition:point,mouseButton:.left) {
            event.setIntegerValueField(.mouseEventWindowUnderMousePointer,value:windowID)
            event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent,value:windowID)
            event.setIntegerValueField(.mouseEventClickState,value:1)
            event.post(tap:.cghidEventTap)
            RunLoop.current.run(until:Date(timeIntervalSinceNow:0.08))
        }
    }
    if let oldPoint=oldPoint {CGWarpMouseCursorPosition(oldPoint)}
    print("CLICK",pid,x,y)
} else {exit(2)}
RunLoop.current.run(until:Date(timeIntervalSinceNow:0.12))
