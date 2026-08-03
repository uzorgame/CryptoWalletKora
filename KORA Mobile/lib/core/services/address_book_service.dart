import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AddressEntry {
  final String label;
  final String address;
  final String blockchain;

  const AddressEntry({
    required this.label,
    required this.address,
    required this.blockchain,
  });

  Map<String, dynamic> toJson() =>
      {'label': label, 'address': address, 'blockchain': blockchain};

  factory AddressEntry.fromJson(Map<String, dynamic> j) => AddressEntry(
        label:      j['label'] as String,
        address:    j['address'] as String,
        blockchain: j['blockchain'] as String,
      );
}

class AddressBookService {
  static const _key = 'kora_address_book';

  static Future<List<AddressEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => AddressEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<AddressEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static Future<void> add(AddressEntry entry) async {
    final entries = await load();
    entries.add(entry);
    await save(entries);
  }

  static Future<void> delete(int index) async {
    final entries = await load();
    if (index < 0 || index >= entries.length) return;
    entries.removeAt(index);
    await save(entries);
  }

  static Future<List<AddressEntry>> forBlockchain(String blockchain) async {
    final entries = await load();
    return entries.where((e) => e.blockchain == blockchain).toList();
  }
}
