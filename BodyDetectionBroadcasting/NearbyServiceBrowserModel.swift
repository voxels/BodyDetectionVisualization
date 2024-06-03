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

open class NearbyServiceBrowserModel: NSObject, ObservableObject {
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
    public var jointRawData = [String:[[String:Any]]]()
    public var lastData: Data?
    public var firstJointData: [String:[JointData]]?
    public var nextJointData: [String:[JointData]]? {
        didSet {
            if let nextJointData = nextJointData, firstJointData == nil {
                firstJointData = nextJointData
            }
        }
    }
    @Published public var frameCount: Int = 0
    public var fitSelected: Bool = false
    @Published var displayLinkTimestamp: Double = 0
    @Published var lastFrameDisplayLinkTimestamp: Double = 0
    var frameDuration: Double = 0.0333333
    public var displayLink: CADisplayLink!
    public var updateTask: Task<Void, Never>?
    public var decodeTask: Task<Void, Never>?
    
    public override init() {
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        self.browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: NearbyServiceBrowserModel.service)
        characterAnchor = AnchorEntity()
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
    
    public func decodeFrame(data: Data) -> [String:[JointData]]? {
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
        print("Did receive data \(data) at \(displayLinkTimestamp)")
        if fitSelected {
            cancelCurrentDecodeTask()
            decodeTask = Task {
                await updateRawData(with: data)
                decodeTask = nil
            }
        }
    }
    
    @MainActor
    public func updateRawData(with data: Data) {
        if let next = decodeFrame(data: data) {
            nextJointData = next
        }
    }
    
    public func cancelCurrentDecodeTask() {
        if let decodeTask = decodeTask, !decodeTask.isCancelled {
            decodeTask.cancel()
            print("cancelled decode task")
        }
        decodeTask = nil
    }

    
    @MainActor
    public func cancelCurrentUpdateTask() {
        if let updateTask = updateTask, !updateTask.isCancelled {
            updateTask.cancel()
            print("cancelled update task")
        }
        updateTask = nil
    }

    
    public func updateFrame() async {
        await MainActor.run {
            
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // Handle stream receiving logic if needed
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // Handle resource receiving start logic if needed
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
        frameCount += 1
    }
}

extension NearbyServiceBrowserModel {
    func decode<T>(_ type: T.Type, from dictionary: [String: Any]) throws -> T where T: Decodable {
        let decoder = JSONDecoder()
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(type, from: data)
    }
}
