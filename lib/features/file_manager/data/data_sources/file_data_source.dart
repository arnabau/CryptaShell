/*
The Metadata Cleaner (Data Source)
This component interacts with the OS hard drive (macOS, Linux, etc.) and, if requested, processes image files to remove EXIF ​​metadata
(GPS coordinates, camera watermarks, dates) by overwriting the raw pixels.
*/

import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

abstract class FileDataSource {
  Future<Uint8List> readFileBytes(File file);
  Future<File> writeFileBytes(String path, Uint8List bytes);
  Uint8List stripMetadata(Uint8List fileBytes);
}

class FileDataSourceImpl implements FileDataSource {
  @override
  Future<Uint8List> readFileBytes(File file) async {
    return await file.readAsBytes();
  }

  @override
  Future<File> writeFileBytes(String path, Uint8List bytes) async {
    final file = File(path);
    return await file.writeAsBytes(bytes,
        flush: true); // 'flush' ensures immediate physical writing to disk
  }

  @override
  Uint8List stripMetadata(Uint8List fileBytes) {
    try {
      // Tried to decode the image (supports JPG, PNG, GIF, WebP)
      final image = img.decodeImage(fileBytes);
      if (image == null)
        return fileBytes; // If it is not a valid image, we return the bytes intact.

      // When re-encoding without passing metadata maps, the 'image' library
      // generates a clean binary file containing only the pixel color matrix.
      return Uint8List.fromList(img.encodeJpg(image, quality: 95));
    } catch (_) {
      // If it fails or is not a compatible image, the original file is returned for safety.
      return fileBytes;
    }
  }
}
