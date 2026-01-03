import 'dart:convert';
import 'dart:io';

import 'package:anecdotes/src/models/models.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

/// A [FileSourceVisitor] that reads file content on IO platforms (mobile/desktop).
///
/// This class provides concrete implementations for reading content from
/// assets, local file paths, network URLs, and future byte streams.
class FileContentVisitor implements FileSourceVisitor<Future<String>> {
  /// Reads the content of an [AssetSource] as a string.
  @override
  Future<String> visitAssetSource(AssetSource source) {
    return rootBundle.loadString(source.path);
  }

  /// Reads the content of a [FutureBytesSource] as a UTF-8 decoded string.
  @override
  Future<String> visitBytesSource(FutureBytesSource bytesAudioSource) async {
    return utf8.decode(await bytesAudioSource.bytesFuture);
  }

  /// Reads the content of a [FilepathSource] as a string.
  @override
  Future<String> visitFilepathSource(FilepathSource source) {
    return File(source.path).readAsString();
  }

  /// Fetches the content of a [NetworkSource] URL and returns it as a UTF-8
  /// decoded string.
  ///
  /// Throws an [Exception] if the HTTP request fails.
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
