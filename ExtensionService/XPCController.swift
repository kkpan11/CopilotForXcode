import Foundation
import Logger
import XPCShared

final class XPCController: XPCServiceDelegate {
    let bridge: XPCCommunicationBridge
    let xpcListener: NSXPCListener
    let xpcServiceDelegate: ServiceDelegate

    var pingTask: Task<Void, Error>?

    init() {
        let bridge = XPCCommunicationBridge(logger: .client)
        let listener = NSXPCListener.anonymous()
        let delegate = ServiceDelegate()
        listener.delegate = delegate
        listener.resume()
        xpcListener = listener
        xpcServiceDelegate = delegate
        self.bridge = bridge

        Task {
            await bridge.setDelegate(self)
            createPingTask()
        }
    }

    deinit {
        xpcListener.invalidate()
        pingTask?.cancel()
    }

    func createPingTask() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                do {
                    try await self.bridge.updateServiceEndpoint(self.xpcListener.endpoint)
                    try await Task.sleep(nanoseconds: 60_000_000_000)
                } catch {
                    try await Task.sleep(nanoseconds: 1_000_000_000)
                    Logger.service
                        .error("Failed to connect to bridge: \(error.localizedDescription)")
                }
            }
        }
    }

    func connectionDidInvalidate() async {
        // ignore
    }

    func connectionDidInterrupt() async {
        createPingTask() // restart the ping task so that it can bring the bridge back immediately.
    }
}

