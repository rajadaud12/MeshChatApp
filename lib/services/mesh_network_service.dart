import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:nearby_connections/nearby_connections.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:audioplayers/audioplayers.dart';

class MeshEndpoint {
  final String id;
  final String name;
  double lat = 0.0;
  double lng = 0.0;
  MeshEndpoint(this.id, this.name);
}

class ChatMessage {
  final String senderId;
  final String senderName;
  final String text;
  final bool isDirect;
  final DateTime timestamp;
  
  ChatMessage({
    required this.senderId,
    required this.senderName,
    required this.text,
    this.isDirect = false,
  }) : timestamp = DateTime.now();
}

class MeshNetworkService extends ChangeNotifier {
  final String userId = "U${Random().nextInt(10000)}";
  final String userName = "User_${Random().nextInt(1000)}";
  final Strategy strategy = Strategy.P2P_CLUSTER;
  
  Map<String, MeshEndpoint> connectedEndpoints = {};
  Map<String, String> pendingEndpoints = {};
  
  List<ChatMessage> groupMessages = [];
  Map<String, List<ChatMessage>> directMessages = {};
  
  Set<String> processedMessageIds = {}; // to prevent infinite loops

  bool isScanning = false;
  double myLat = 0.0;
  double myLng = 0.0;
  
  Timer? _locationTimer;
  final AudioPlayer audioPlayer = AudioPlayer();

  MeshNetworkService() {
    _initNetwork();
  }

  Future<void> _initNetwork() async {
    await requestPermissions();
    await _getCurrentLocation();
    startMesh();
    
    // Periodically broadcast location
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (isScanning) {
        _getCurrentLocation().then((_) {
          _broadcastLocation();
        });
      }
    });
  }

  Future<void> requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.microphone,
    ].request();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      myLat = position.latitude;
      myLng = position.longitude;
      notifyListeners();
    } catch (e) {
      print("Location error: $e");
    }
  }

  Future<void> startMesh() async {
    try {
      bool a = await Nearby().startAdvertising(
        userName,
        strategy,
        onConnectionInitiated: _onConnectionInit,
        onConnectionResult: (id, status) {
          if (status == Status.CONNECTED) {
            connectedEndpoints[id] = MeshEndpoint(id, pendingEndpoints[id] ?? "Unknown");
            notifyListeners();
            _broadcastLocation(); // send initial location
          } else {
            connectedEndpoints.remove(id);
            pendingEndpoints.remove(id);
            notifyListeners();
          }
        },
        onDisconnected: (id) {
          connectedEndpoints.remove(id);
          pendingEndpoints.remove(id);
          notifyListeners();
        },
      );

      bool b = await Nearby().startDiscovery(
        userName,
        strategy,
        onEndpointFound: (id, name, serviceId) {
          Nearby().requestConnection(
            userName,
            id,
            onConnectionInitiated: _onConnectionInit,
            onConnectionResult: (id, status) {
              if (status == Status.CONNECTED) {
                connectedEndpoints[id] = MeshEndpoint(id, pendingEndpoints[id] ?? name);
                notifyListeners();
                _broadcastLocation();
              } else {
                connectedEndpoints.remove(id);
                pendingEndpoints.remove(id);
                notifyListeners();
              }
            },
            onDisconnected: (id) {
              connectedEndpoints.remove(id);
              pendingEndpoints.remove(id);
              notifyListeners();
            },
          );
        },
        onEndpointLost: (id) {},
      );

      isScanning = a && b;
      notifyListeners();
    } catch (e) {
      print("Mesh initialization error: $e");
    }
  }

  void _onConnectionInit(String id, ConnectionInfo info) {
    pendingEndpoints[id] = info.endpointName;
    
    Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endid, payload) async {
        if (payload.type == PayloadType.BYTES) {
          String rawData = String.fromCharCodes(payload.bytes!);
          _handleRawMessage(endid, rawData);
        } else if (payload.type == PayloadType.FILE) {
          // Play audio file
        }
      },
      onPayloadTransferUpdate: (endid, payloadTransferUpdate) async {
        if (payloadTransferUpdate.status == PayloadStatus.SUCCESS) {
          // If it's a file, payload ID can be used to find uri
          // Wait for file transfer complete
          // We can use nearby.payloadToUri(payloadTransferUpdate.id)
          // But for simplicity we might just send audio as bytes if it's short, or handle file differently.
        }
      },
    );
  }

  void _handleRawMessage(String fromId, String rawData) {
    try {
      final data = jsonDecode(rawData);
      final msgId = data['msgId'];
      
      if (processedMessageIds.contains(msgId)) return;
      processedMessageIds.add(msgId);
      
      final type = data['type'];
      if (type == 'LOC') {
        final senderId = data['senderId'];
        if (connectedEndpoints.containsKey(senderId)) {
          connectedEndpoints[senderId]!.lat = data['lat'];
          connectedEndpoints[senderId]!.lng = data['lng'];
          notifyListeners();
        }
        _forwardRawMessage(rawData, excludeId: fromId);
      } else if (type == 'CHAT') {
        final chat = ChatMessage(
          senderId: data['senderId'],
          senderName: data['senderName'],
          text: data['text'],
          isDirect: false,
        );
        groupMessages.add(chat);
        notifyListeners();
        _forwardRawMessage(rawData, excludeId: fromId);
      } else if (type == 'DIRECT') {
        // Direct messages are 1-hop, so `fromId` is the sender.
        final chat = ChatMessage(
          senderId: fromId,
          senderName: data['senderName'],
          text: data['text'],
          isDirect: true,
        );
        directMessages.putIfAbsent(fromId, () => []).add(chat);
        notifyListeners();
      } else if (type == 'VOICE') {
        // Voice payload encoded as base64 string
        final targetId = data['targetId'];
        if (targetId == 'ALL' || targetId == userId) {
          String base64Audio = data['audio'];
          Uint8List audioBytes = base64Decode(base64Audio);
          _playAudioBytes(audioBytes);
          
          if (targetId == 'ALL') {
            _forwardRawMessage(rawData, excludeId: fromId);
          }
        } else {
          _forwardRawMessage(rawData, excludeId: fromId);
        }
      }
    } catch (e) {
      print("Message parse error: $e");
    }
  }

  void _broadcastLocation() {
    if (myLat == 0.0 && myLng == 0.0) return;
    
    final payload = jsonEncode({
      'msgId': '${userId}_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'LOC',
      'senderId': userId,
      'lat': myLat,
      'lng': myLng,
    });
    _forwardRawMessage(payload);
  }

  void sendGroupMessage(String text) {
    final chat = ChatMessage(senderId: userId, senderName: userName, text: text, isDirect: false);
    groupMessages.add(chat);
    notifyListeners();
    
    final payload = jsonEncode({
      'msgId': '${userId}_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'CHAT',
      'senderId': userId,
      'senderName': userName,
      'text': text,
    });
    _forwardRawMessage(payload);
  }

  void sendDirectMessage(String targetId, String text) {
    final chat = ChatMessage(senderId: userId, senderName: userName, text: text, isDirect: true);
    directMessages.putIfAbsent(targetId, () => []).add(chat);
    notifyListeners();
    
    final payload = jsonEncode({
      'msgId': '${userId}_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'DIRECT',
      'senderName': userName,
      'text': text,
    });
    Nearby().sendBytesPayload(targetId, Uint8List.fromList(utf8.encode(payload)));
  }

  void sendVoiceData(Uint8List audioBytes) {
    // encode to base64 for reliable transmission over string payload
    String base64Audio = base64Encode(audioBytes);
    final payload = jsonEncode({
      'msgId': '${userId}_${DateTime.now().millisecondsSinceEpoch}',
      'type': 'VOICE',
      'senderId': userId,
      'targetId': 'ALL',
      'audio': base64Audio,
    });
    _forwardRawMessage(payload);
  }

  void _forwardRawMessage(String rawData, {String? excludeId}) {
    List<int> bytes = utf8.encode(rawData);
    for (String endId in connectedEndpoints.keys) {
      if (endId != excludeId) {
        Nearby().sendBytesPayload(endId, Uint8List.fromList(bytes));
      }
    }
  }
  
  void _playAudioBytes(Uint8List bytes) async {
    // using audioplayers Source bytes
    await audioPlayer.play(BytesSource(bytes));
  }

  Future<void> stopMesh() async {
    _locationTimer?.cancel();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    await Nearby().stopAllEndpoints();
    connectedEndpoints.clear();
    pendingEndpoints.clear();
    isScanning = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    audioPlayer.dispose();
    super.dispose();
  }
}
