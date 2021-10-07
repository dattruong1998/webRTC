import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:sdp_transform/sdp_transform.dart';

class RTCScreen extends StatefulWidget {
  @override
  _RTCScreenState createState() => _RTCScreenState();
}

class _RTCScreenState extends State<RTCScreen> {
  bool _isOffer = false;
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  RTCVideoRenderer _localView = new RTCVideoRenderer();
  RTCVideoRenderer _remoteView = new RTCVideoRenderer();
  final configController = TextEditingController();

  @override
  void initState() {
    initialize();
    super.initState();
  }

  initialize() async {
    await _localView.initialize();
    await _remoteView.initialize();
    _peerConnection = await _createPeerConnecion();
  }

  _openUserMedia() async {
    final Map<String, dynamic> constraints = {
      'audio': true,
      'video': {
        'facingMode': 'user',
      },
    };
    MediaStream stream = await navigator.mediaDevices.getUserMedia(constraints);
    _localView.srcObject = stream;
    return stream;
  }

  void _createOffer() async {
    RTCSessionDescription description =
    await _peerConnection!.createOffer();
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    _isOffer = true;
    _peerConnection!.setLocalDescription(description);
  }

  void _createAnswer() async {
    RTCSessionDescription description =
    await _peerConnection!.createAnswer();
    var session = parse(description.sdp.toString());
    print(json.encode(session));
    _peerConnection!.setLocalDescription(description);
  }

  void _setRemoteDescription() async {
    String jsonString = configController.text;
    dynamic session = await jsonDecode('$jsonString');
    String sdp = write(session, null);
    RTCSessionDescription description =
    new RTCSessionDescription(sdp, _isOffer ? 'answer' : 'offer');
    await _peerConnection!.setRemoteDescription(description);
  }

  _createPeerConnecion() async {
    //Open user media
    _localStream = await _openUserMedia();

    Map<String, dynamic> configuration = {
      "iceServers": [
        {"url": "stun:stun.l.google.com:19302"},
      ]
    };

    final Map<String, dynamic> offerSdpConstraints = {
      "mandatory": {
        "OfferToReceiveAudio": true,
        "OfferToReceiveVideo": true,
      },
      "optional": [],
    };

    RTCPeerConnection _connection =
    await createPeerConnection(configuration, offerSdpConstraints);
    _connection.addStream(_localStream!);

    //observe ice candidate
    _connection.onIceCandidate = (e) {
      if (e.candidate != null) {
        print(json.encode({
          'candidate': e.candidate.toString(),
          'sdpMid': e.sdpMid.toString(),
          'sdpMlineIndex': e.sdpMlineIndex,
        }));
      }
    };

    //observe state candidat
    _connection.onIceConnectionState = (e) {
      print(e);
    };

    // set stream for remoteView
    _connection.onAddStream = (stream) {
      try{
        _remoteView.srcObject = stream;
      }catch(e) {
        print(e);
      }
    };

    return _connection;
  }

  void _addCandidate() async {
    String jsonString = configController.text;
    dynamic session = await jsonDecode('$jsonString');
    dynamic candidate =
    new RTCIceCandidate(session['candidate'], session['sdpMid'], session['sdpMlineIndex']);
    await _peerConnection!.addCandidate(candidate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: Column(
          children: [
            Expanded(child: Row(
              children: [
                Expanded(child: RTCVideoView(_localView, mirror: true), flex: 2,),
                Expanded(child: RTCVideoView(_remoteView), flex: 2),
              ],
            ),flex: 4),
            Expanded(child: Column(
              children: [
                Expanded(child: Row(
                  children: [
                    ElevatedButton(onPressed: (){
                      _createOffer();
                    }, child: Text("Create offer")),
                    SizedBox(width: 50),
                    ElevatedButton(onPressed: (){
                      _setRemoteDescription();
                    }, child: Text("Remote")),
                    SizedBox(width: 50),
                    ElevatedButton(onPressed: (){
                      _createAnswer();
                    }, child: Text("Create Answer")),
                    SizedBox(width: 50),
                    ElevatedButton(onPressed: (){
                      _addCandidate();
                    }, child: Text("Add Candidate")),
                  ],
                ), flex: 3),
                Expanded(child: TextFormField(
                  controller: configController,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  maxLength: TextField.noMaxLength,
                ), flex: 3)
              ],
            ), flex: 2),
          ],
        )
    );
  }
}

