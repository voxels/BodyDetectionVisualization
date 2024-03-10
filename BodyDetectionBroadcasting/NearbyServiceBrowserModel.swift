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

open class NearbyServiceBrowserModel :NSObject, ObservableObject {
    static public let service = "body-tracking"
    let myPeerId = MCPeerID(displayName: UIDevice.current.name)
    public let session: MCSession
    public let browser:MCNearbyServiceBrowser
    @Published public var isConnected:Bool = false
    public var jointRawData = [[String:Any]]()
    public var nextJointData:[JointData]?
    public var lastJointData:[JointData]?
    public var frameCount:Int = 0
    public var skipFrames:Int = 1
    @Published var displayLinkTimestamp:Double = 0
    @Published var lastFrameDisplayLinkTimestamp:Double = 0
    var frameDuration:Double = 0.0333333
    public var displayLink:CADisplayLink!
    private var decodeTask:Task<Void, Never>?
    public override init() {
        self.session = MCSession(peer: myPeerId, securityIdentity: nil, encryptionPreference: .none)
        self.browser = MCNearbyServiceBrowser(peer: myPeerId, serviceType: NearbyServiceBrowserModel.service)
        
        super.init()
        session.delegate = self
        createDisplayLink()
    }
    
    public func startBrowsing(){
        browser.startBrowsingForPeers()
    }
    
    public func stopBrowsing(){
        browser.stopBrowsingForPeers()
    }
    
    public func deviceLocation() {
        
    }
}

extension NearbyServiceBrowserModel : MCBrowserViewControllerDelegate {
    public func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        
    }
    
    public func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        
    }
    
    public func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
        return true
    }
}

extension NearbyServiceBrowserModel : MCSessionDelegate {
    @MainActor
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state{
            
        case .notConnected:
            Task{ @MainActor in
                isConnected = false
            }
            
        case .connecting:
            Task{ @MainActor in
                isConnected = false
            }
        case .connected:
            Task{ @MainActor in
                isConnected = true
            }
        @unknown default:
            fatalError()
        }
    }
    
    @MainActor
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        do{
            if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [[String:Any]]{
                jointRawData = jsonObject
                if displayLinkTimestamp < lastFrameDisplayLinkTimestamp + displayLink.duration * Double(skipFrames) {
                    return
                }
            
                if decodeTask != nil {
                    decodeTask?.cancel()
                }
                decodeTask = Task{ @MainActor in
                    if Task.isCancelled { return }
                    var newJointData = [JointData]()
                    do {
                        for rawData in jointRawData {
                            let decodedData = try decode(JointData.self, from: rawData)
                            newJointData.append(decodedData)
                        }
                        decodeTask = nil
                        frameCount = 0
                        lastJointData = nextJointData
                        nextJointData = newJointData
                        lastFrameDisplayLinkTimestamp = displayLinkTimestamp
                    } catch {
                        print(error)
                    }
                    
                }
            }
        } catch{
            print(error)
        }
        
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        
    }
    
    
}



extension NearbyServiceBrowserModel {
    private func createDisplayLink() {
        displayLink = CADisplayLink(target: self, selector:#selector(onFrame(link:)))
        displayLink.add(to: .main, forMode: .default)
    }
}


extension NearbyServiceBrowserModel {
    
    @objc func onFrame(link:CADisplayLink) {
        frameCount += 1
        frameDuration = link.duration
        displayLinkTimestamp = link.timestamp
    }
}

extension NearbyServiceBrowserModel {
    func decode<T>(_ type: T.Type, from dictionary: [String: Any]) throws -> T where T : Decodable {
        let decoder = JSONDecoder()
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(type, from: data)
    }
}
