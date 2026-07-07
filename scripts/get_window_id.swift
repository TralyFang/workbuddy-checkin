#!/usr/bin/env swift
// get_window_id.swift - 获取指定应用的 CGWindowID
// 用法: swift get_window_id.swift <应用名称>

import CoreGraphics
import Foundation

let appName = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "WorkBuddy"

guard let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
    exit(1)
}

var selectedWindowID: Int?
var selectedWindowArea = 0

for window in windowList {
    guard let ownerName = window[kCGWindowOwnerName as String] as? String,
          let windowID = window[kCGWindowNumber as String] as? Int,
          let layer = window[kCGWindowLayer as String] as? Int,
          let bounds = window[kCGWindowBounds as String] as? [String: Any],
          let width = bounds["Width"] as? Int,
          let height = bounds["Height"] as? Int else {
        continue
    }

    if !ownerName.contains(appName) || layer != 0 || width <= 0 || height <= 0 {
        continue
    }

    let area = width * height
    if area > selectedWindowArea {
        selectedWindowArea = area
        selectedWindowID = windowID
    }
}

if let selectedWindowID {
    print(selectedWindowID)
    exit(0)
}

exit(1)
