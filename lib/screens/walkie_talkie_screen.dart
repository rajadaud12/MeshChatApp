import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../services/mesh_network_service.dart';

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen> with SingleTickerProviderStateMixin {
  bool _isSpeaking = false;
  late AnimationController _pulseController;
  final AudioRecorder _audioRecorder = AudioRecorder();
  String? _tempPath;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _initTempPath();
  }

  Future<void> _initTempPath() async {
    final dir = await getTemporaryDirectory();
    _tempPath = '${dir.path}/walkie_talkie_temp.m4a';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _onTalkPressed(TapDownDetails details) async {
    if (await _audioRecorder.hasPermission() && _tempPath != null) {
      setState(() {
        _isSpeaking = true;
      });
      _pulseController.repeat();
      
      await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: _tempPath!);
    }
  }

  Future<void> _onTalkReleased(TapUpDetails details) async {
    await _stopAndSend();
  }

  Future<void> _onTalkCanceled() async {
    await _stopAndSend();
  }
  
  Future<void> _stopAndSend() async {
    if (!_isSpeaking) return;
    
    setState(() {
      _isSpeaking = false;
    });
    _pulseController.stop();
    _pulseController.reset();
    
    final path = await _audioRecorder.stop();
    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) {
          Provider.of<MeshNetworkService>(context, listen: false).sendVoiceData(bytes);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final meshService = context.watch<MeshNetworkService>();
    final connectedCount = meshService.connectedEndpoints.length;

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Walkie-Talkie',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Icon(Icons.speaker_phone, color: Colors.white54),
            ],
          ),
        ),
        
        // Channel Info
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.emergency, color: Theme.of(context).primaryColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Global Mesh Channel',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      'Broadcasting to $connectedCount nodes',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: Colors.white54),
            ],
          ),
        ),
        
        Expanded(
          child: Center(
            child: GestureDetector(
              onTapDown: _onTalkPressed,
              onTapUp: _onTalkReleased,
              onTapCancel: _onTalkCanceled,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      // Pulse Effect
                      if (_isSpeaking) ...[
                        _buildPulseRings(300 + (_pulseController.value * 100), 0.1),
                        _buildPulseRings(220 + (_pulseController.value * 80), 0.2),
                      ],
                      
                      // PTT Button
                      Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: _isSpeaking 
                              ? [
                                  Theme.of(context).primaryColor,
                                  const Color(0xFF00B8FF),
                                ]
                              : [
                                  Colors.white.withOpacity(0.1),
                                  Colors.white.withOpacity(0.05),
                                ],
                          ),
                          boxShadow: _isSpeaking
                            ? [
                                BoxShadow(
                                  color: Theme.of(context).primaryColor.withOpacity(0.5),
                                  blurRadius: 30,
                                  spreadRadius: 10,
                                )
                              ]
                            : [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                )
                              ],
                          border: Border.all(
                            color: _isSpeaking 
                              ? Colors.white.withOpacity(0.5) 
                              : Colors.white.withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isSpeaking ? Icons.mic : Icons.mic_none,
                              size: 64,
                              color: _isSpeaking ? Colors.black : Colors.white70,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _isSpeaking ? 'RECORDING & SENDING' : 'HOLD TO TALK',
                              style: TextStyle(
                                color: _isSpeaking ? Colors.black87 : Colors.white54,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        
        // Status Text
        Padding(
          padding: const EdgeInsets.only(bottom: 48.0),
          child: Text(
            _isSpeaking 
              ? 'Transmitting audio via mesh relay...' 
              : 'Ready. Encrypted P2P connection.',
            style: TextStyle(
              color: _isSpeaking ? Theme.of(context).primaryColor : Colors.white38,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPulseRings(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).primaryColor.withOpacity(opacity * (1.0 - _pulseController.value)),
        border: Border.all(
          color: Theme.of(context).primaryColor.withOpacity(opacity * 2 * (1.0 - _pulseController.value)),
          width: 1,
        ),
      ),
    );
  }
}
