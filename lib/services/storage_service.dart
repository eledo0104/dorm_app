import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class StorageService {
  /// Uploads [imageBytes] to Firebase Storage under duty_proofs/
  /// Returns the public download URL.
  static Future<String> uploadDutyProof({
    required Uint8List imageBytes,
    required String scheduleId,
    required String userId,
  }) async {
    final fileName = '${scheduleId}_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final ref = FirebaseStorage.instance
        .ref()
        .child('duty_proofs')
        .child(fileName);

    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
    );

    await ref.putData(imageBytes, metadata);
    return await ref.getDownloadURL();
  }
}
