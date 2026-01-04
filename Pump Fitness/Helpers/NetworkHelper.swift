import Foundation
import Network

class NetworkHelper {
    static let shared = NetworkHelper()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkHelper")
    private var currentPath: NWPath?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.queue.async {
                self?.currentPath = path
            }
        }
        monitor.start(queue: queue)
    }
    
    func getNetworkInfo() -> [String: Any] {
        return queue.sync {
            var info: [String: Any] = [:]
            
            if let path = currentPath {
                var types: [String] = []
                if path.usesInterfaceType(.wifi) { types.append("wifi") }
                if path.usesInterfaceType(.cellular) { types.append("cellular") }
                if path.usesInterfaceType(.wiredEthernet) { types.append("ethernet") }
                if path.usesInterfaceType(.loopback) { types.append("loopback") }
                if path.usesInterfaceType(.other) { types.append("other") }
                
                info["connectionTypes"] = types
                info["status"] = path.status == .satisfied ? "satisfied" : (path.status == .unsatisfied ? "unsatisfied" : "requiresConnection")
                info["isExpensive"] = path.isExpensive
                info["isConstrained"] = path.isConstrained
            } else {
                info["status"] = "unknown"
            }
            
            return info
        }
    }
}
