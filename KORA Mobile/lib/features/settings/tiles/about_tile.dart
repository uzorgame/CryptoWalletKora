import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kora/features/settings/widgets/settings_tile.dart';

// The version row, and the tap-counter behind it.

class AboutTile extends StatefulWidget {
  const AboutTile({super.key});

  @override
  State<AboutTile> createState() => _AboutTileState();
}

class _AboutTileState extends State<AboutTile> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = 'v${info.version}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      icon: Icons.info_outline_rounded,
      label: 'About',
      value: _version,
      onTap: () => debugPrint('[TAP] About (version=$_version) (settings_screen.dart)'),
    );
  }
}
