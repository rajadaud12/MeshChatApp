import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import '../services/mesh_network_service.dart';
import 'direct_chat_screen.dart';

class RadarScreen extends StatefulWidget {
  const RadarScreen({super.key});

  @override
  State<RadarScreen> createState() => _RadarScreenState();
}

class _RadarScreenState extends State<RadarScreen> with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  void _showNodeDetails(String id, MeshEndpoint endpoint) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _NodeDetailsSheet(nodeId: id, endpoint: endpoint),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meshService = context.watch<MeshNetworkService>();
    final nodes = meshService.connectedEndpoints.entries.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Nearby Devices',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    meshService.isScanning ? 'Scanning for mesh nodes...' : 'Mesh stopped.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white54,
                    ),
                  ),
                ],
              ),
              Icon(
                Icons.bluetooth_searching, 
                color: meshService.isScanning ? const Color(0xFF00FF88) : Colors.white54
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Radar Rings and Sweep
                SizedBox(
                  width: 340,
                  height: 340,
                  child: AnimatedBuilder(
                    animation: _sweepController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: RadarPainter(
                          sweepAngle: _sweepController.value * 2 * math.pi,
                          primaryColor: Theme.of(context).primaryColor,
                        ),
                      );
                    },
                  ),
                ),
                
                // Nodes
                ...nodes.asMap().entries.map((entry) {
                  final endpoint = entry.value.value;
                  double angle = 0;
                  double distance = 0.5; // default fallback
                  
                  if (meshService.myLat != 0.0 && endpoint.lat != 0.0) {
                    final distMeters = Geolocator.distanceBetween(
                      meshService.myLat, meshService.myLng, 
                      endpoint.lat, endpoint.lng
                    );
                    final bearing = Geolocator.bearingBetween(
                      meshService.myLat, meshService.myLng, 
                      endpoint.lat, endpoint.lng
                    );
                    
                    angle = bearing < 0 ? 360 + bearing : bearing;
                    // Scale distance: max 1000m on radar
                    distance = (distMeters / 1000.0).clamp(0.1, 1.0);
                  } else {
                    // Fallback visual
                    final idHash = entry.value.key.hashCode;
                    angle = (idHash % 360).toDouble();
                    distance = 0.3 + ((idHash % 70) / 100.0);
                  }
                  
                  return _buildNodeWidget(entry.value.key, endpoint, angle, distance);
                }),
                
                // Center Device (You)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStat('Nodes', '${nodes.length}'),
              _buildStat('Active', meshService.isScanning ? 'Yes' : 'No', color: meshService.isScanning ? Theme.of(context).primaryColor : Colors.red),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStat(String label, String value, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white54,
          ),
        ),
      ],
    );
  }

  Widget _buildNodeWidget(String id, MeshEndpoint endpoint, double angle, double distance) {
    final radius = 170.0 * distance;
    final rad = (angle - 90) * (math.pi / 180.0); // -90 so 0 bearing is top
    final dx = radius * math.cos(rad);
    final dy = radius * math.sin(rad);

    final intensity = 1.0 - (distance * 0.5);

    return Transform.translate(
      offset: Offset(dx, dy),
      child: GestureDetector(
        onTap: () => _showNodeDetails(id, endpoint),
        child: Container(
          width: 16 * intensity,
          height: 16 * intensity,
          decoration: BoxDecoration(
            color: const Color(0xFF00B8FF),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00B8FF).withOpacity(0.5 * intensity),
                blurRadius: 8 * intensity,
                spreadRadius: 1,
              )
            ],
          ),
        ),
      ),
    );
  }
}

class RadarPainter extends CustomPainter {
  final double sweepAngle;
  final Color primaryColor;

  RadarPainter({required this.sweepAngle, required this.primaryColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);

    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ringPaint);
    }
    
    canvas.drawLine(
        Offset(center.dx, 0), Offset(center.dx, size.height), ringPaint);
    canvas.drawLine(
        Offset(0, center.dy), Offset(size.width, center.dy), ringPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        colors: [
          primaryColor.withOpacity(0.0),
          primaryColor.withOpacity(0.1),
          primaryColor.withOpacity(0.5),
        ],
        stops: const [0.0, 0.8, 1.0],
        transform: GradientRotation(sweepAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      sweepAngle - math.pi / 2 - math.pi / 4, 
      math.pi / 4,
      true,
      sweepPaint,
    );
  }

  @override
  bool shouldRepaint(covariant RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}

class _NodeDetailsSheet extends StatelessWidget {
  final String nodeId;
  final MeshEndpoint endpoint;

  const _NodeDetailsSheet({required this.nodeId, required this.endpoint});

  @override
  Widget build(BuildContext context) {
    final meshService = context.watch<MeshNetworkService>();
    String distStr = "Unknown";
    
    if (meshService.myLat != 0 && endpoint.lat != 0) {
      final d = Geolocator.distanceBetween(meshService.myLat, meshService.myLng, endpoint.lat, endpoint.lng);
      distStr = "${d.toInt()}m";
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF00B8FF).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.router,
                  color: Color(0xFF00B8FF),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      endpoint.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      'Mesh Relay Node',
                      style: TextStyle(
                        color: Color(0xFF00B8FF),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildDetailRow('Device ID', nodeId, Icons.perm_identity),
          const SizedBox(height: 16),
          _buildDetailRow('Real Distance', distStr, Icons.social_distance),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context); // close sheet
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DirectChatScreen(targetId: nodeId, targetName: endpoint.name),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.chat_bubble),
              label: const Text(
                'Direct Message',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.white54),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
