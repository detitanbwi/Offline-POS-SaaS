class AuthUser {
  final String id;
  final String nama;
  final String role; // 'pemilik' or 'kasir'

  const AuthUser({
    required this.id,
    required this.nama,
    required this.role,
  });

  bool get isOwner => role == 'pemilik';
  bool get isCashier => role == 'kasir';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nama': nama,
      'role': role,
    };
  }

  factory AuthUser.fromMap(Map<String, dynamic> map) {
    return AuthUser(
      id: map['id'] as String,
      nama: map['nama'] as String,
      role: map['role'] as String,
    );
  }
}
