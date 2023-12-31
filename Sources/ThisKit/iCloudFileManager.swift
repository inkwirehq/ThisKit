//
//  FileManager.swift
//  AppPrivacyInsights (iOS)
//
//  Created by hexagram on 2021/11/11.
//

import Foundation

// https://theswiftdev.com/how-to-use-icloud-drive-documents/
public class ICloudFileManager {
  public enum PIFileManagerError: Error {
    case iCloudStorageIsUnavailable
  }

  public let containerUrl: URL

  public var syncDirUrl: URL {
    containerUrl.appendingPathComponent("Sync", isDirectory: true)
  }
  
  public var currentDeviceSyncDir: URL {
    syncDirUrl
      .appendingPathComponent(Device.id()!.uuidString, isDirectory: true)
  }

  public init() throws {
    guard let url = FileManager.default.url(forUbiquityContainerIdentifier: nil) else {
      TKLog("\(PIFileManagerError.iCloudStorageIsUnavailable)")
      throw PIFileManagerError.iCloudStorageIsUnavailable
    }
    self.containerUrl = url.appendingPathComponent("Documents", isDirectory: true)
    try self.initSyncDir()
  }
  
  public func initSyncDir() throws {
    try findOrCreateSyncDir()
    try findOrCreateCurrentDeviceSyncDir()
    try manualTriggerSync()
  }

  public func findOrCreateSyncDir() throws {
    try FileManager.default.findOrCreateDir(at: syncDirUrl)
  }

  public func findOrCreateCurrentDeviceSyncDir() throws {
    try FileManager.default.findOrCreateDir(at: currentDeviceSyncDir)
  }
  
  /// By touch a file
  public func manualTriggerSync() throws {
    let url = syncDirUrl.appendingPathComponent(UUID().uuidString, isDirectory: false)
    if FileManager.default.createFile(atPath: url.path, contents: "Manual Trigger Sync".data(using: .utf8)) {
      try FileManager.default.removeIfExists(at: url)
    }
  }

  public func forceWrite(at url: URL, data: Data) throws {
    if FileManager.default.fileExists(atPath: url.path, isDirectory: nil) {
      try FileManager.default.removeItem(at: url)
    }
    TKLog(url.path)
    try data.write(to: url, options: [])
  }
  
  /// https://medium.com/@RomainP_design/download-a-file-from-icloud-swift-4-ad074494b8c9
  public func downloadICloudFile(from url: URL) async throws {
    try FileManager.default.startDownloadingUbiquitousItem(at: url)
    var lastPathComponent = url.lastPathComponent
    if lastPathComponent.contains(".icloud") {
      lastPathComponent.removeFirst()
      let downloadedFilePath = url
        .deletingLastPathComponent()
        .appendingPathComponent(
          lastPathComponent.replacingOccurrences(of: ".icloud", with: ""),
          isDirectory: false
        ).path
      var isDownloaded = false
      while !isDownloaded {
        TKLog("Downloading File At: \(downloadedFilePath)")
        if FileManager.default.fileExists(atPath: downloadedFilePath) {
          isDownloaded = true
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
      }
    }
  }

  /// include sync download
  public func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions = []) async throws -> [URL] {
    let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    for url in urls {
      try await downloadICloudFile(from: url)
    }
    let res = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: mask)
    return res
  }

  /// Dangerous
  public func cleanAllSync() -> Result<Void, Error> {
    do {
      try FileManager.default.removeIfExists(at: syncDirUrl)
    } catch {
      return .failure(error)
    }
    return .success(())
  }
}
