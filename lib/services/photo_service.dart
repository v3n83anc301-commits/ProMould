import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'log_service.dart';

/// Result class for photo operations with error details
class PhotoResult {
  final String? url;
  final String? error;
  final bool cancelled;

  PhotoResult({this.url, this.error, this.cancelled = false});

  bool get success => url != null && error == null;
}

class PhotoService {
  static final _picker = ImagePicker();
  static final _storage = FirebaseStorage.instance;

  /// Capture and upload with detailed error reporting
  static Future<PhotoResult> captureAndUploadWithResult(String issueId) async {
    try {
      final picked =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
      if (picked == null) return PhotoResult(cancelled: true);
      
      final file = File(picked.path);
      if (!await file.exists()) {
        return PhotoResult(error: 'Captured file not found');
      }
      
      final name =
          'issues/$issueId/photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      final ref = _storage.ref().child(name);
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      return PhotoResult(url: url);
    } on FirebaseException catch (e) {
      LogService.error('Firebase upload error', e);
      return PhotoResult(error: 'Upload failed: ${e.message}');
    } catch (e) {
      LogService.error('Photo upload error', e);
      return PhotoResult(error: 'Photo capture failed: $e');
    }
  }

  static Future<String?> captureAndUpload(String issueId) async {
    final result = await captureAndUploadWithResult(issueId);
    return result.url;
  }

  static Future<String?> chooseAndUpload(String issueId) async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return null;
      final file = File(picked.path);
      final name =
          'issues/$issueId/photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      final ref = _storage.ref().child(name);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      LogService.error('Photo upload error', e);
      return null;
    }
  }

  static Future<String?> captureMouldPhoto(String mouldId) async {
    try {
      LogService.debug('Opening camera for mould $mouldId');
      final picked =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);

      if (picked == null) {
        LogService.debug('Camera cancelled by user');
        return null;
      }

      LogService.debug('Photo captured: ${picked.path}');
      final file = File(picked.path);

      if (!await file.exists()) {
        LogService.error('Captured file does not exist', picked.path);
        return null;
      }

      final name =
          'moulds/$mouldId/photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      LogService.debug('Uploading to Firebase Storage: $name');

      final ref = _storage.ref().child(name);
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      LogService.info('Mould photo uploaded successfully: $url');
      return url;
    } catch (e, stackTrace) {
      LogService.error('Mould photo capture error', e);
      LogService.error('Stack trace: $stackTrace', null);
      return null;
    }
  }

  static Future<String?> uploadMouldPhoto(String mouldId) async {
    try {
      LogService.debug('Opening image picker for mould $mouldId');
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);

      if (picked == null) {
        LogService.debug('Image picker cancelled by user');
        return null;
      }

      LogService.debug('Image picked: ${picked.path}');
      final file = File(picked.path);

      if (!await file.exists()) {
        LogService.error('Picked file does not exist', picked.path);
        return null;
      }

      final name =
          'moulds/$mouldId/photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      LogService.debug('Uploading to Firebase Storage: $name');

      final ref = _storage.ref().child(name);
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();

      LogService.info('Mould photo uploaded successfully: $url');
      return url;
    } catch (e, stackTrace) {
      LogService.error('Mould photo upload error', e);
      LogService.error('Stack trace: $stackTrace', null);
      return null;
    }
  }

  static Future<String?> uploadDowntimePhoto(String downtimeId) async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return null;
      final file = File(picked.path);
      final name =
          'downtime/$downtimeId/photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      final ref = _storage.ref().child(name);
      final uploadTask = await ref.putFile(file);
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      LogService.error('Downtime photo upload error', e);
      return null;
    }
  }

  /// Upload with detailed result for better error handling in UI
  static Future<PhotoResult> uploadDowntimePhotoWithResult(String downtimeId) async {
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70);
      if (picked == null) return PhotoResult(cancelled: true);
      
      final file = File(picked.path);
      if (!await file.exists()) {
        return PhotoResult(error: 'Selected file not found');
      }
      
      final name =
          'downtime/$downtimeId/photo_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}';
      final ref = _storage.ref().child(name);
      final uploadTask = await ref.putFile(file);
      final url = await uploadTask.ref.getDownloadURL();
      return PhotoResult(url: url);
    } on FirebaseException catch (e) {
      LogService.error('Firebase upload error', e);
      return PhotoResult(error: 'Upload failed: ${e.message}');
    } catch (e) {
      LogService.error('Downtime photo upload error', e);
      return PhotoResult(error: 'Photo upload failed: $e');
    }
  }
}
