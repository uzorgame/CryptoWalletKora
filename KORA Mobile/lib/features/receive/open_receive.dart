import 'package:flutter/material.dart';
import 'package:kora/core/models/asset.dart';
import 'package:kora/core/utils/page_transitions.dart';
import 'package:kora/features/receive/receive_picker_screen.dart';
import 'package:kora/features/receive/receive_screen.dart';

// The one entry point into receiving: one asset goes straight to its address, several
// go through the picker.

void openReceivePicker(BuildContext context, List<Asset> assets) {
  if (assets.isEmpty) return;
  if (assets.length == 1) {
    context.pushModal(ReceiveScreen(preselectedAsset: assets.first));
    return;
  }
  context.pushModal(ReceivePickerScreen(assets: assets));
}
