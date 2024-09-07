//
//  ErrorHandler.swift
//
//
//  Created by hexagram on 2023/7/6.
//

import AsyncAlgorithms
import Foundation
import SwiftUI

@Observable public final class TKErrorHandler {
  public static let `default` = TKErrorHandler()

  let logger: TKLogger

  @MainActor public let errorQueue: AsyncChannel<NSError> = .init()
//  @MainActor @Published var error: NSError?
//  @MainActor @Published var didError = false

  public enum AnyError: Error {
    case any(String)
  }

  public init(logger: TKLogger = TKLogger(category: "TKErrorHandler")) {
    self.logger = logger
  }

  public func handle(err: NSError) {
    Task {
      logger.error(err.debugDescription)
      await self.errorQueue.send(err)
    }
  }

  public func handle(string: String) {
    handle(err: AnyError.any(string) as NSError)
  }

  public func handle(_ block: () throws -> Void) {
    do {
      try block()
    } catch let err as NSError {
      self.handle(err: err)
    } catch let any {
      let err = AnyError.any(any.localizedDescription) as NSError
      self.handle(err: err)
    }
  }

  public func handle(_ block: () async throws -> Void) async {
    do {
      try await block()
    } catch let err as NSError {
      self.handle(err: err)
    } catch let any {
      let err = AnyError.any(any.localizedDescription) as NSError
      self.handle(err: err)
    }
  }

  public struct TKErrorHandlerModifier: ViewModifier {
    @Environment(TKErrorHandler.self) private var errorHandler
    @State private var didError = false
    @State private var error: NSError? = nil

    public init() {}

    public func body(content: Content) -> some View {
      content
        .task {
          for await err in self.errorHandler.errorQueue {
            didError = true
            error = err
          }
        }
        .alert(
          "Error!",
          isPresented: $didError,
          presenting: error) { _ in
            Button(role: .cancel) {
            } label: {
              Text("OK")
            }
        } message: { err in
          switch err as Error {
          case let TKErrorHandler.AnyError.any(str):
            Text(str)
          default:
            Text(err.debugDescription)
          }
        }
    }
  }
}
