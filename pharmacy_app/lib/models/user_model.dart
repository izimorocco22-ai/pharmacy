class User {
  final String id;
  final String fullName;
  final String? email;
  final String phone;
  final String role;
  final bool isVerified;

  User({
    required this.id,
    required this.fullName,
    this.email,
    required this.phone,
    required this.role,
    required this.isVerified,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'],
      phone: json['phone'] ?? '',
      role: json['role'] ?? '',
      isVerified: json['isVerified'] ?? false,
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
    };
  }
}
