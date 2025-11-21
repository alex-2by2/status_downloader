import 'dart:typed_data';
import 'package:flutter/services.dart';

class AndroidSaf {
  static const MethodChannel _channel = MethodChannel('com.statusdownloader/saf');

  static Future<String?> openDocumentTree() async {
    final res = await _channel.invokeMethod('openDocumentTree');
    return res as String?;
  }

  static Future<List<dynamic>> listFiles(String treeUri) async {
    final res = await _channel.invokeMethod('listFilesInTree', { 'uri': treeUri });
    return res as List<dynamic>;
  }

  static Future<bool> takePersistablePermission(String uri, int mode) async {
    final res = await _channel.invokeMethod('takePersistablePermission', { 'uri': uri, 'mode': mode });
    return res == true;
  }

  static Future<bool> deleteDocument(String uri) async {
    final res = await _channel.invokeMethod('deleteDocument', { 'uri': uri });
    return res == true;
  }

  static Future<List<String>> copyDocumentsToPictures(List<String> uris) async {
    final res = await _channel.invokeMethod('copyDocumentsToPictures', { 'uris': uris });
    return List<String>.from(res ?? []);
  }

  static Future<bool> openDocument(String uri) async {
    final res = await _channel.invokeMethod('openDocument', { 'uri': uri });
    return res == true;
  }

  static Future<bool> openDocumentInApp(String uri) async {
    final res = await _channel.invokeMethod('openDocumentInApp', { 'uri': uri });
    return res == true;
  }

  static Future<Uint8List?> readFileBytes(String uri, {int maxBytes = -1}) async {
    final res = await _channel.invokeMethod('readFileBytes', { 'uri': uri, 'maxBytes': maxBytes });
    if (res == null) return null;
    return Uint8List.fromList(List<int>.from(res));
  }
}
