#!/usr/bin/env swift
// request_accessibility.swift - 触发 macOS 辅助功能权限检查/弹窗

import ApplicationServices
import Foundation

let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
let isTrusted = AXIsProcessTrustedWithOptions(options)

print(isTrusted ? "trusted" : "not_trusted")
exit(isTrusted ? 0 : 1)
