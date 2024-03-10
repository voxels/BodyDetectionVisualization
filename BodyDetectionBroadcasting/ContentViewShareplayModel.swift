//
//  ContentViewShareplayModel.swift
//  BodyDetectionBroadcasting
//
//  Created by Michael A Edgcumbe on 3/6/24.
//


import Foundation
import RealityKit
import Combine
import GroupActivities
import QuartzCore

open class ContentViewShareplayModel: NSObject, ObservableObject {
    
    static let shared = ContentViewShareplayModel()
    @Published var isActivated = false
    @Published var isReady = false
    var isFetchingAttachments = false
    private var subscriptions = Set<AnyCancellable>()
    public var attachmentHistory:[GroupSessionJournal.Attachment] = [GroupSessionJournal.Attachment]()
    public var jointAttachmentHistory:[[String:JointData]] = [[String:JointData]]()
    @Published var groupSession: GroupSession<DanceCoordinator>? {
           didSet {
               if let groupSession = groupSession {
                   let messenger = GroupSessionMessenger(session: groupSession, deliveryMode: .unreliable)
                   self.messenger = messenger
                   let journal = GroupSessionJournal(session: groupSession)
                   self.journal = journal
                   print("did set group session")
               }
           }
       }
    
    @Published public var coordinator:DanceCoordinator?
    public var messenger:GroupSessionMessenger?
    public var journal:GroupSessionJournal?
    @Published public var presentSharingView = false
    @Published public var nextJointData:[String:JointData] = [String:JointData]()

    @Published public var lastJointData:[String:JointData]?
    @Published public var jointHistory:[JointData] = [JointData]()
    private var decodeTask:Task<Void, Never>?

    let skipFrames:Int = 3
    public var frameCount:Int = 0
    public var displayLink:CADisplayLink!
    
    public var jointRawData = [[String:Any]]()
    @Published var displayLinkTimestamp:Double = 0
    @Published var lastFrameDisplayLinkTimestamp:Double = 0
    
    override public init() {
        super.init()
        createDisplayLink()
    }
    
    @discardableResult
    public func createCoordinator() async->DanceCoordinator {
        let activity = DanceCoordinator()
        coordinator = activity
        return activity
}
    
    @MainActor
    public func startAdvertisingDevice() async
    {
        print("Sharing activity")
//       await shareActivity()
//        print("Joining coordinator")
//        await joinDanceCoordinator()
    }
}


extension ContentViewShareplayModel {
    private func createDisplayLink() {
        displayLink = CADisplayLink(target: self, selector:#selector(onFrame(link:)))
        displayLink.add(to: .main, forMode: .default)
    }
}

extension ContentViewShareplayModel {
    
    @objc func onFrame(link:CADisplayLink) {
        displayLinkTimestamp = link.timestamp
     }
}

extension ContentViewShareplayModel {
    @MainActor
    public func handle(message:[String:JointData]) {
        let receiveMessage = message
        Task {
            lastJointData = nextJointData
            nextJointData = receiveMessage
            print("Handling message \(displayLinkTimestamp)")
            lastFrameDisplayLinkTimestamp = displayLinkTimestamp
        }
    }
    
    @MainActor
    public func shareActivity() async {
        
        guard let coordinator = coordinator else  {
            return
        }
        
        // Await the result of the preparation call.
        switch await coordinator.prepareForActivation() {
            
        case .activationDisabled:
            print("Activation disabled")
        case .activationPreferred:
            do {
                let isActive = try await coordinator.activate()
                print("Activated activity \(isActive)")
            } catch {
                print("Unable to activate the activity: \(error)")
            }
            
        case .cancelled:
            print("cancelled")
            break
            
        default: ()
        }
    }
    
    @MainActor
    func configureGroupSession(_ groupSession: GroupSession<DanceCoordinator>) {
        print("Configure group session \(groupSession.activeParticipants)")
        self.groupSession = groupSession
        Task {
            await joinDanceCoordinator(groupSession: groupSession)
        }
    }
    
    @MainActor
    public func joinDanceCoordinator(groupSession:GroupSession<DanceCoordinator>) async {
            // Set the app's active group session.
            // Remove previous subscriptions.
            subscriptions.removeAll()
            
            // Observe changes to the session state.
            groupSession.$state.sink { [weak self] state in
                if case .invalidated = state {
                    // Set the groupSession to nil to publish
                    // the invalidated session state.
                    self?.messenger = nil
                    self?.journal = nil
                    self?.subscriptions.removeAll()
                    self?.groupSession = nil
                    self?.isActivated = false
                    self?.isReady = false
                    print("Invalidated Session")
                } else if case .joined = state {
                    self?.isActivated = true
                    print("joined session")
                }
            }.store(in: &subscriptions)
            
        if groupSession.state != .joined {
            // Join the session to participate in playback coordination.
            print("joining group session")
            groupSession.join()
        }
            
            groupSession.$activity.sink { [weak self] activity in
                print("activity is active:\(activity.id)")
                self?.isReady = true
            }.store(in: &subscriptions)
        }
}



extension ContentViewShareplayModel {
    func decode<T>(_ type: T.Type, from dictionary: [String: Any]) throws -> T where T : Decodable {
        let decoder = JSONDecoder()
        let data = try JSONSerialization.data(withJSONObject: dictionary, options: [])
        return try decoder.decode(type, from: data)
    }
}
