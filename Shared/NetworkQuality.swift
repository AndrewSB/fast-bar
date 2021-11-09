//
//  NetworkQuality.swift
//  fast-bar
//
//  Created by Andrew Breckenridge on 11/1/21.
//

import Foundation
import Combine
import Network


class NetworkQuality {
    
    private(set) var display: AnyPublisher<String, Never>!
    
    @Published private var connectionState: NWPath.Status? = nil
    @Published private var speed: SpeedInfo? = nil
    @Published private var forceRefreshSubject = PassthroughSubject<Void, Never>()

    private let startTime = Date()
    private let monitorQueue = DispatchQueue(label: "fast-bar_Network_Background", qos: .background)
    private let monitor = NWPathMonitor()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        monitor.pathUpdateHandler = { [weak self] in
            self?.connectionState = $0.status
            self?.speed = nil
        }
        monitor.start(queue: monitorQueue)
        
        Publishers.Merge3(
            $connectionState.map { _ in },
            Timer.TimerPublisher.init(interval: 75, tolerance: 20, runLoop: RunLoop.current, mode: RunLoop.Mode.default).autoconnect().map { _ in },
            forceRefreshSubject
        )
            .receive(on: monitorQueue)
            .flatMap { [unowned self] _ -> Future<SpeedInfo, Never> in
                print("testing quality \(startTime.timeIntervalSinceNow)")
                return networkQuality()
            }
            .sink {
                self.speed = $0
            }
            .store(in: &cancellables)
        
        self.display = Publishers.CombineLatest($connectionState, $speed)
            .map { state, speed in
                switch state {
                case .unsatisfied:
                    return "Offline"
                case .requiresConnection:
                    return "Captive connection?"
                case .satisfied:
                    guard let speed = speed else {
                        return "testing network..."
                    }
                    
                    return speed.formatted()
                    
                case .none:
                    return "initializing connection..."

                @unknown default:
                    return "unhandled state: \(state.debugDescription)"
                }
            }
            .eraseToAnyPublisher()
    }

    func forceRefresh() {
        forceRefreshSubject.send()
    }
}

private func networkQuality() -> Future<SpeedInfo, Never> {
    return Future { promise in
        assert(!Thread.isMainThread)
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/networkQuality")
        task.arguments = ["-c"]
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        task.launch()
        task.waitUntilExit()
        
        let theHandle = outputPipe.fileHandleForReading
        let data = theHandle.readDataToEndOfFile()
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print(task)
            return
        }
        
        print(String(data: data, encoding: .utf8)?.debugDescription as Any)
        print(json)
        promise(.success(SpeedInfo(ping: json["responsiveness"] as! Int, upload: json["ul_throughput"] as! Int, download: json["dl_throughput"] as! Int)))
    }
}

struct SpeedInfo: Equatable {
    let ping: Int
    let upload: Int
    let download: Int

    func formatted() -> String {
        let up = ByteCountFormatter.string(fromByteCount: Int64(upload), countStyle: ByteCountFormatter.CountStyle.memory)
        let down = ByteCountFormatter.string(fromByteCount: Int64(download), countStyle: ByteCountFormatter.CountStyle.memory)
        
        if ping == 0 {
            return "↑\(up) ↓\(down)"
        } else {
            return "\(ping)ms ↑\(up) ↓\(down)"
        }
    }
}
