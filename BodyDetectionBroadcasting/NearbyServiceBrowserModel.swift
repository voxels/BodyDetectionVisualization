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
    public var jointRawData = [String:[[String:Any]]]()
    public var allData:[Data] = []
    public var firstJointData:[String:[JointData]]?
    public var nextJointData:[String:[JointData]]? {
        didSet {
            if let nextJointData = nextJointData, firstJointData == nil {
                firstJointData = nextJointData
            }
        }
    }
    public var lastJointData:Data = Data()
    public var jointDataHistory:[[String:[JointData]]] = []
    @Published public var frameCount:Int = 0
    @Published public var countDataFrames:Int = 0
    @Published public var frameReady:Bool = false
    public var skipFrames:Int = 0
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
    
    public func decodeFrame(data:Data)->[String:[JointData]]? {
        do{
            if !data.isEmpty  {
                let jsonObject = try JSONSerialization.jsonObject(with: data)
                let rawData = jsonObject as! [String : [[String : Any]]]
                do {
                    var newJointData = [String:[JointData]]()
                    for key in rawData.keys {
                        var jointData = [JointData]()
                        let rawData = rawData[key]!
                        for rawDatum in rawData {
                            let decodedData = try decode(JointData.self, from: rawDatum)
                            jointData.append(decodedData)
                        }
                        jointData.sort { data, checkData in
                            data.d.i < checkData.d.i && data.d.t < checkData.d.t
                        }
                        newJointData[jointData.first!.d.ident] = jointData
                    }
                    return newJointData
                } catch {
                    print(error)
                }
            }
        } catch{
            print(error)
        }
        return nil
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
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        //print("did receive data \(data)")
        allData.append(data)
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
        displayLink.preferredFramesPerSecond = 60
        displayLink.add(to: .main, forMode: .default)
    }
}


extension NearbyServiceBrowserModel {
    
    @objc func onFrame(link:CADisplayLink) {
        frameDuration = link.targetTimestamp-link.timestamp
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
