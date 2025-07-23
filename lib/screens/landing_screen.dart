import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'home_screen.dart';
import 'audio_home_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({Key? key}) : super(key: key);

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Request media permissions where necessary
    await [
      Permission.videos,
      Permission.audio,
      Permission.storage, // for Android < 13
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = 80.0;
    return Scaffold(
      appBar: AppBar(title: const Text('Media Player')),
      body: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _FeatureTile(
              icon: Icons.play_circle_fill,
              label: 'Video',
              iconSize: iconSize,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HomeScreen()),
              ),
            ),
            _FeatureTile(
              icon: Icons.library_music,
              label: 'Audio',
              iconSize: iconSize,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AudioHomeScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final double iconSize;
  final VoidCallback onTap;
  const _FeatureTile({
    required this.icon,
    required this.label,
    required this.iconSize,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: iconSize + 20,
            height: iconSize + 20,
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: iconSize, color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }
}
