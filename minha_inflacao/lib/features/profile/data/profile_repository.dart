import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String? cep5;
  final bool consentSharing;

  const UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    this.cep5,
    required this.consentSharing,
  });

  factory UserProfile.fromFirestore(String uid, Map<String, dynamic> data) => UserProfile(
        uid: uid,
        displayName: data['displayName'] as String? ?? '',
        email: data['email'] as String? ?? '',
        cep5: data['cep5'] as String?,
        consentSharing: data['consentSharing'] as bool? ?? false,
      );
}

class ProfileRepository {
  final FirebaseFirestore _db;

  ProfileRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  Stream<UserProfile?> watchProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromFirestore(uid, snap.data()!);
    });
  }

  Future<void> updateCep5(String uid, String cep5) =>
      _db.collection('users').doc(uid).update({'cep5': cep5});

  Future<void> updateConsentSharing(String uid, bool consent) =>
      _db.collection('users').doc(uid).update({
        'consentSharing': consent,
        'consentAt': FieldValue.serverTimestamp(),
      });
}
