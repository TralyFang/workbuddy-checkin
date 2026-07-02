#!/usr/bin/env swift
// get_window_id.swift - 获取指定应用的 CGWindowID
// 用法: swift get_window_id.swift <应用名称>

import CoreGraphics
import Foundation

let appName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "WorkBuddy"

guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

for window in windowList {
    guard let ownerName = window[kCGWindowOwnerName as String] as? String,
          let windowID = window[kCGWindowNumber as String] as? Int else {
        continue
    }
    if ownerName.contains(appName) {
        print(windowID)
        exit(0)
    }
}

// 未找到窗口
exit(1)
