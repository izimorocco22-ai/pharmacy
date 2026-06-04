class User {
  final String id;
  final String fullName;
  final String? email;
  final String phone;
  final String role;
  final bool isVerified;
  final String? profileImage;

  User({
    required this.id,
    required this.fullName,
    this.email,
    required this.phone,
    required this.role,
    required this.isVerified,
    this.profileImage,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      fullName: json['fullName'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      role: json['role'] ?? 'patient',
      isVerified: json['isVerified'] ?? false,
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'phone': phone,
      'role': role,
      'isVerified': isVerified,
      'profileImage': profileImage,
    };
  }
}
