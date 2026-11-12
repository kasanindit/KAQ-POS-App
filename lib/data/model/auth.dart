class AuthUser {
  final String id;
  final String username;
  final String displayName;

  const AuthUser({
    required this.id,
    required this.username,
    required this.displayName,
  });

  factory AuthUser.fromMap(Map<String, Object?> map) {
    return AuthUser(
      id: map['id'] as String,
      username: map['username'] as String,
      displayName: map['display_name'] as String,
    );
  }
}
