import Foundation
import WebRTC
import Firebase
import ARKit


enum User: String {
    case caller
    case receiver
}

// The WebRTC network manager for connecting two devices together
class NetworkManager: NSObject {
    
    private let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        let videoEncoderFactory = RTCDefaultVideoEncoderFactory()
        let videoDecoderFactory = RTCDefaultVideoDecoderFactory()
        return RTCPeerConnectionFactory(encoderFactory: videoEncoderFactory, decoderFactory: videoDecoderFactory)
    }()
    
    let rtcConfig = RTCConfiguration()
    let rtcAudioSession = RTCAudioSession.sharedInstance()
    var peerConnection: RTCPeerConnection?
    var rtcConstant: RTCMediaConstraints?
    var dataChannel: RTCDataChannel?
    
    var localVideoCapturer: RTCCameraVideoCapturer?
    var localVideoSource: RTCVideoSource?
    var localVideoTrack: RTCVideoTrack?
    var remoteVideoTrack: RTCVideoTrack?
    
    var remoteAudioTrack: RTCAudioTrack?
    
    var answerListener: ListenerRegistration?
    var offerListener: ListenerRegistration?
    var candidateListener: ListenerRegistration?
    
    var loudspeakerEnabled: Bool = false
    
    private let audioQueue = DispatchQueue(label: "audio")
    
    var user: User!
    
    let db = Firestore.firestore()
    
    init(_ user: User) {
        rtcConfig.bundlePolicy = RTCBundlePolicy.maxCompat
        // The following servers are publically available TURN/STUN servers. Do not assume they are secure or that they will continue to work. Ideally you should host your own server. However TURN/STUN servers are not needed when connecting over a wifi network if this is your use case.
        rtcConfig.iceServers = [RTCIceServer(urlStrings: ["stuns:stun.l.google.com:19302"]),
                                RTCIceServer(urlStrings: ["stuns:stun1.l.google.com:19302"]),
                                RTCIceServer(urlStrings: ["stuns:stun1.2.google.com:19302"]),
                                RTCIceServer(urlStrings: ["stuns:stun1.3.google.com:19302"]),
                                RTCIceServer(urlStrings: ["turn:numb.viagenie.ca"], username: "muazkh", credential: "webrtc@live.com")]
        
        // For details on unified plan see: https://www.callstats.io/blog/what-is-unified-plan-and-how-will-it-affect-your-webrtc-development
        rtcConfig.sdpSemantics = .unifiedPlan

        rtcConstant = RTCMediaConstraints(mandatoryConstraints: ["OfferToReceiveAudio": "true", "OfferToReceiveVideo": "false"], optionalConstraints: nil)
        
        peerConnection = factory.peerConnection(with: rtcConfig, constraints: rtcConstant!, delegate: nil)

        self.user = user
        super.init()
        
        createMediaSenders()
        addCandidateListener()
        switch user {
        case .caller:
            // Add the data channel
            addDataChannel()
        case .receiver:
            // Ensure that any data in the Firestore database due to a previous connection is wiped
            db.collection("connectionData").document("callerOffer").delete()
            db.collection("connectionData").document("receiverAnswer").delete()
            // Add database listeners
            addOfferSdpListener()
        }
        
    }
    
    func createMediaSenders() {
        let streamId = "stream"
        
        // Audio
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = factory.audioSource(with: audioConstraints)
        let audioTrack = factory.audioTrack(with: audioSource, trackId: "Audio0")
        peerConnection?.add(audioTrack, streamIds: [streamId])
    }
        
    //********************************************************************************************************************************************//
    //                                       Methods used by the caller for signaling                                                             //
    //********************************************************************************************************************************************//
    
    private func addDataChannel() {
        let dataChannelConfig = RTCDataChannelConfiguration()
        
        dataChannelConfig.maxRetransmits = 0
        dataChannelConfig.isOrdered = false
        dataChannelConfig.isNegotiated = false
        
        dataChannel = peerConnection?.dataChannel(forLabel: "Face Data", configuration: dataChannelConfig)
    }
    
    
    func connect() {
        // Ensure that any data in the Firestore database due to a previous connection is wiped
        db.collection("connectionData").document("callerOffer").delete()
        db.collection("connectionData").document("receiverAnswer").delete()
        print("Connection started")
        addAnswerSdpListener()
        // Send the offer
        peerConnection?.offer(for: rtcConstant!) { (localDescription, error) in
            print("Offer created")
            // A local description is generated
            guard let localDescription = localDescription else { return }
            print(error?.localizedDescription as Any)
            // Update the Firestore database with the local description
            self.db.collection("connectionData").document("callerOffer").setData([ "sdp": localDescription.sdp], merge: false)
            print("Offer sent to server")
            print("The offer sdp was \(localDescription.sdp)")
            
            // Set the local description
            self.peerConnection?.setLocalDescription(localDescription) { (error) in
                print("Offer set as local description")
                if let error = error {
                    print(error.localizedDescription as Any)
                }
                
            }
        }
        
    }
    
    
    func updateCandidate(with candidate: RTCIceCandidate) {
        // Turn the RTCIceCandidate into a dictionary
        var data: [String : Any] = ["sdp": candidate.sdp,
                                    "sdpMLineIndex": candidate.sdpMLineIndex]
        // The data of sdpMid may or may not need to be added
        if let sdpMid = candidate.sdpMid {
            data["sdpMid"] = sdpMid
        }
        // Update the Firestore database with the dictionary representation of the candidate
        self.db.collection("connectionData").document("\(user.rawValue)" + "Candidate").setData(data, merge: false)
        print("Candidate sent to server")
    }
    
    
    func addAnswerSdpListener() {
        print("Adding answer listener")
        answerListener = db.collection("connectionData").document("receiverAnswer").addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            let sdp = data["sdp"] as! String
            print("Answer sdp obtained from server")
            // Create an RTCSessionDescription from the string representation of the remote description
            let remoteDescription = RTCSessionDescription(type: .answer, sdp: sdp)
            // Set the remote description
            self.peerConnection?.setRemoteDescription(remoteDescription) { (error) in
                print("Answer sdp set as remote description")
                // Handle any errors
                if let error = error {
                    print(error.localizedDescription as Any)
                }
            }
            
        }
    }
    
    
    //********************************************************************************************************************************************//
    //                                       Methods used by the receiver for signaling                                                           //
    //********************************************************************************************************************************************//
    
    // Add a listener for the offer description
    func addOfferSdpListener() {
        offerListener = db.collection("connectionData").document("callerOffer").addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            let sdp = data["sdp"] as! String
            // Create an RTCSessionDescription object from the string representation of the remote description
            let remoteDescription = RTCSessionDescription(type: .offer, sdp: sdp)
            // Tell the peerConnection object what the remote description is
            self.peerConnection?.setRemoteDescription(remoteDescription) { (error) in
                // Print any errors
                print(error?.localizedDescription as Any)
                // Create an answer description
                self.peerConnection?.answer(for: self.rtcConstant!) { (answerDescription, error) in
                    // Make sure the answer is not nil
                    guard let answerDescription = answerDescription else { return }
                    // If there is an error, print it
                    if let error = error {
                        print(error.localizedDescription as Any)
                    }
                    // Update the Firestore database with the answer description
                    self.db.collection("connectionData").document("receiverAnswer").setData([ "sdp": answerDescription.sdp], merge: false)
                    print("The answer sdp was \(answerDescription.sdp)")
                    // Set the local description to the answer description
                    self.peerConnection?.setLocalDescription(answerDescription) { (error) in
                        // If there is an error, print it
                        print(error?.localizedDescription as Any)
                    }
                }
                
            }
        }
    }
    
    //********************************************************************************************************************************************//
    //                                               Methods used by both for signaling                                                           //
    //********************************************************************************************************************************************//
    
    
    func addCandidateListener() {
        var documentName = ""
        switch user {
        case .caller:
            documentName = "receiverCandidate"
        case .receiver:
            documentName = "callerCandidate"
        case .none:
            break
        }
        
        candidateListener = db.collection("connectionData").document(documentName).addSnapshotListener { documentSnapshot, error in
            guard let document = documentSnapshot else {
                print("Error fetching document: \(error!)")
                return
            }
            guard let data = document.data() else {
                print("Document data was empty.")
                return
            }
            let sdp = data["sdp"] as! String
            let sdpMLineIndex = data["sdpMLineIndex"] as! Int32
            let sdpMid = data["sdpMid"] as? String
            let rtcIceCandidate = RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
            self.peerConnection?.add(rtcIceCandidate)
            print("Added ice candidate")
        }
    }
    
    
    //********************************************************************************************************************************************//
    //                                                      Other methods                                                                         //
    //********************************************************************************************************************************************//
    
    
    // Close the connection and remove the Firebase listeners
    func closeConnection() {
        self.peerConnection?.close()
        self.peerConnection = nil
        answerListener?.remove()
        offerListener?.remove()
        candidateListener?.remove()
    }
    
    // Send the face blendshapes and the orientation of the face and eyes to the other device via the WebRTC data channel
    func send(_ blendshapes: [ARFaceAnchor.BlendShapeLocation: NSNumber],
              _ faceOrientation: SCNQuaternion,
              _ leftEyeOrientation: SCNQuaternion,
              _ rightEyeOrientation: SCNQuaternion) {

        let blendshapeArray = blendshapes.convertToArray()
        let faceOrientation = faceOrientation.convertToArray()
        let leftEyeOrientation = leftEyeOrientation.convertToArray()
        let rightEyeOrientation = rightEyeOrientation.convertToArray()
        
        let jsonArray = [blendshapeArray, faceOrientation, leftEyeOrientation, rightEyeOrientation]
        // Convert the blendshape and transform array to JSON and then send it over WebRTC
        let encoder = JSONEncoder()
        let data = try! encoder.encode(jsonArray)
        let dataBuffer = RTCDataBuffer(data: data, isBinary: false)
        dataChannel?.sendData(dataBuffer)
    }
    
    // Initialize the audio and turns the iPhone loudspeaker on. The following code is from https://github.com/stasel/WebRTC-iOS
    func initializeAudio() {
        self.audioQueue.async { [weak self] in
            guard let self = self else {
                return
            }
            self.rtcAudioSession.lockForConfiguration()
            do {
                try self.rtcAudioSession.setCategory(AVAudioSession.Category.playAndRecord.rawValue)
                try self.rtcAudioSession.overrideOutputAudioPort(.speaker)
                try self.rtcAudioSession.setActive(true)
                self.loudspeakerEnabled = true
            } catch let error {
                debugPrint("Couldn't force audio to speaker: \(error)")
            }
            self.rtcAudioSession.unlockForConfiguration()
        }
    }
    
}
