import 'dart:convert';
import 'dart:io';

import 'package:anecdotes/src/models/models.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class FileContentVisitor implements FileSourceVisitor<Future<String>> {
  @override
  Future<String> visitAssetSource(AssetSource source) {
    return rootBundle.loadString(source.path);
  }

  @override
  Future<String> visitBytesSource(FutureBytesSource bytesAudioSource) async {
    return utf8.decode(await bytesAudioSource.bytesFuture);
  }

  @override
  Future<String> visitFilepathSource(FilepathSource source) {
    return File(source.path).readAsString();
  }

  @override
  Future<String> visitNetworkSource(NetworkSource source) async {
    final url = source.url;
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to load network file: $url');
    }
    return utf8.decode(response.bodyBytes);
  }
}
