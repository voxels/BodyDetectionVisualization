//
//  NearbyServiceBrowserModel.swift
//  BodyTrackingVisualization
//
//  Created by Michael A Edgcumbe on 2/13/24.
//
import Foundation
import RealityKit
import Combine
import MultipeerConnectivity

public enum NearbyServiceBrowserModelError: Error {
    case DecodeFailure
}

open class NearbyServiceBrowserModel: NSObject, ObservableObject {
    public var characterRotation:AnchorEntity
    public var characterAnchor: AnchorEntity
    public var sceneEntity: Entity?
    public var originEntity: Entity?
    @Published public var skeletonIdentityEntity: ModelEntity?
    public var characterLeftHandAnchor: Entity?
    public var characterRightHandAnchor: Entity?
    public var characterLeftFootAnchor: Entity?
    public var characterRightFootAnchor: Entity?
    @Published public var domeEntity: ModelEntity?
    
    static public let service = "body-tracking"
    let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    public let session: MCSession
    public let browser: MCNearbyServiceBrowser
    @Published public var isConnected: Bool = false
    @Published public var lastData: NSData?
    public var firstJointData: [String:[JointData]]?
    public var nextJointData: [String:[JointData]]?
    @Published public var frameCount: Int = 0
    public var fitSelected: Bool = false
    @Published var displayLinkTimestamp: Double = 0
    private var receivedDataTimestamp:Double = 0
    @Published var lastFrameDisplayLinkTimestamp: Double = 0
    var frameDuration: Double = 0.0333333
    public var displayLink: CADisplayLink!
    public var updateTask: Task<Void, Never>?
    // Define a variable to hold the Task
    var decodeTask: Task<[String:[JointData]]?, Error>?
    // Initialize the task in an initializer or a method
    // An example async function that returns a value and can throw an error
    
    // Define a lock for synchronization
    private let lock = NSLock()
    
    // Define a queue for background decoding
    private let decodingQueue = DispatchQueue(label: "decodingQueue", qos: .background)
    
    func performDecodeAsyncOperation() async -> [String:[JointData]]? {
        guard let data = lastData as? Data else {
            return nil
        }
        
        return await Task.detached(priority: .background){ [weak self] in
            self?.createDecodeTask(with: data)
        }.value
    }
    
    // Optionally, a method to start the task
    func startDecodeTask() async throws {
        cancelCurrentDecodeTask()
        decodeTask = Task(priority: .background) {
            if Task.isCancelled {
                print("returning cancelled task")
                return [String:[JointData]]()
            }
            return await performDecodeAsyncOperation()
        }
        try await handleDecodeTaskResult()
        decodeTask = nil
    }
    
    // A method to handle the task result
    func handleDecodeTaskResult() async throws {
        if Task.isCancelled {
            print("Returning cancelled task with no value")
            decodeTask = nil
            return
        }
        let value = await decodeTask?.result.map { result in
            switch result {
            case .some(let data):
                return data
            case .none:
                print("Task failed with error")
                return [String:[JointData]]()
            }
        }
        
        if let jointData = try value?.get() {
            Task { @MainActor in
                if nextJointData != jointData {
                    nextJointData = jointData
                    print("Swapped joint data")
                }
            }
        }
    }
    
    public func cancelCurrentDecodeTask() {
        if let decodeTask = decodeTask, !decodeTask.isCancelled {
            cancelDecodeTask()
            print("cancelled decode task")
        }
    }
    
    
    // Optionally, a method to cancel the task
    func cancelDecodeTask() {
        decodeTask?.cancel()
    }
    
    public override init() {
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        self.browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: NearbyServiceBrowserModel.service)
        characterAnchor = AnchorEntity()
        characterRotation = AnchorEntity()
        characterRotation.addChild(characterAnchor)
        super.init()
        session.delegate = self
        createDisplayLink()
    }
    
    public func startBrowsing() {
        browser.startBrowsingForPeers()
    }
    
    public func stopBrowsing() {
        browser.stopBrowsingForPeers()
    }
    
    public func leaveSession() {
        session.disconnect()
    }
    
    public func decodeFrame(data: Data?) -> [String:[JointData]]? {
        guard let data = data else {
            return nil
        }
        do {
            if !data.isEmpty {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                guard let rawData = jsonObject as? [String : [[String : Any]]] else {
                    print("Invalid JSON format")
                    return nil
                }
                
                var newJointData = [String:[JointData]]()
                for (_, rawJointData) in rawData {
                    var jointData = [JointData]()
                    for rawDatum in rawJointData {
                        let decodedData = try decode(JointData.self, from: rawDatum)
                        jointData.append(decodedData)
                    }
                    if let firstJoint = jointData.first {
                        newJointData[firstJoint.d.ident] = jointData
                    }
                }
                return newJointData
            }
        } catch {
            print(error)
        }
        return nil
    }
    
    public func send(fitSelected:Bool) throws {
        guard isConnected else {
            return
        }
        let isReadyDict = ["fitSelected":fitSelected]
        let jsonData = try JSONSerialization.data(withJSONObject: isReadyDict, options: [])
        try session.send(jsonData, toPeers: session.connectedPeers, with: .reliable)
        print("sending fitSelected: \(isReadyDict)")
    }
    
    public func send(frameReady:Bool) throws {
        guard isConnected else {
            return
        }
        let isReadyDict = ["frameReady":frameReady]
        let jsonData = try JSONSerialization.data(withJSONObject: isReadyDict, options: [])
        try session.send(jsonData, toPeers: session.connectedPeers, with: .unreliable)
        print("sending frameReady: \(isReadyDict)")
    }
}

extension NearbyServiceBrowserModel: MCBrowserViewControllerDelegate {
    public func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        // Handle completion logic if needed
    }
    
    public func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        // Handle cancellation logic if needed
        browser.stopBrowsingForPeers()
    }
    
    public func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
        return true
    }
}

extension NearbyServiceBrowserModel: MCSessionDelegate {
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .notConnected, .connecting:
            Task { @MainActor in
                isConnected = false
            }
        case .connected:
            Task { @MainActor in
                isConnected = true
            }
        @unknown default:
            fatalError("Unknown state received: \(state)")
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        if receivedDataTimestamp == displayLinkTimestamp {
            return
        }
        lock.lock()

        Task { @MainActor in
            defer { lock.unlock() }

            do {
                let last = try (data as NSData).decompressed(using: .lz4)
                print("did receive data \(last.count) \(displayLinkTimestamp)")
                lastData = last
            } catch {
                print(error)
            }
            receivedDataTimestamp = displayLinkTimestamp
        }
    }
    
    public func createDecodeTask(with data:Data) -> [String:[JointData]]? {
        return decodeFrame(data: data)
    }
    
    @MainActor
    public func cancelCurrentUpdateTask() {
        if let updateTask = updateTask, !updateTask.isCancelled {
            updateTask.cancel()
            print("cancelled update task")
        }
    }
    
    
    @MainActor
    public func updateFrame() {
        frameCount += 1
        print("Frame: \(frameCount)\t\(displayLinkTimestamp)")
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle stream receiving logic if needed
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Handle resource receiving start logicf if needed
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        // Handle resource receiving completion logic if needed
    }
}

extension NearbyServiceBrowserModel {
    private func createDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(onFrame(link:)))
        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: .main, forMode: .default)
    }
}

extension NearbyServiceBrowserModel {
    @MainActor @objc func onFrame(link: CADisplayLink) {
        frameDuration = link.targetTimestamp - link.timestamp
        displayLinkTimestamp = link.timestamp
        
        decodingQueue.async { [weak self] in
            guard let self = self else { return }
            self.lock.lock()
            Task {
                defer { self.lock.unlock() }

                do {
                    try await self.startDecodeTask()
                } catch {
                    print(error)
                }
            }
        }
    }
}

extension NearbyServiceBrowserModel {
    func decode<T>(_ type: T.Type, from dictionary: [String: Any]) throws -> T where T: Decodable {
        let decoder = JSONDecoder()
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(type, from: data)
    }
}
