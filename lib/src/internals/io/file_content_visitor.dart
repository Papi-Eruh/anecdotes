import 'package:anecdotes/src/models/models.dart';

class FileContentVisitor implements FileSourceVisitor<Future<String>> {
  @override
  Future<String> visitAssetSource(AssetSource source) {
    throw UnsupportedError('Assets are not supported on web.');
  }

  @override
  Future<String> visitBytesSource(FutureBytesSource bytesAudioSource) {
    throw UnsupportedError('Bytes are not supported on web.');
  }

  @override
  Future<String> visitFilepathSource(FilepathSource source) {
    throw UnsupportedError('Filepaths are not supported on web.');
  }

  @override
  Future<String> visitNetworkSource(NetworkSource source) {
    throw UnsupportedError('Network are not supported on web.');
  }
}
