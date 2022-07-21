import 'dart:developer';

import 'package:hmi_app/models/role.dart';

class User {
  /*
  Response from the IDM
  {
    "organizations": [],
    "displayName": "",
    "roles": [],
    "app_id": "tutorial-dckr-site-0000-xpresswebapp",
    "trusted_apps": [],
    "isGravatarEnabled": false,
    "email": "alice-the-admin@test.com",
    "id": "aaaaaaaa-good-0000-0000-000000000000",
    "app_azf_domain": "",
    "username": "alice",
    "trusted_applications": []
  }
  */

  final String displayName;
  final String email;
  final String id;
  final List<String> roles = []; // the ids of the user roles
  final List<String>? organizations;
  final String? appId;
  final bool? isGravatarEnabled;
  final String? username;
  final List<String>? trustedApplications;

  User({
    required this.displayName,
    required this.id,
    required this.email,
    this.organizations,
    this.appId,
    this.isGravatarEnabled,
    this.username,
    this.trustedApplications,
  });

  factory User.fromJSON(Map<String, dynamic> json) {
    return User(
      displayName: json["displayName"],
      email: json["email"],
      id: json["id"],
    );
  }

  @override
  String toString() {
    return '''User: $displayName
      email: $email
      roles: $roles''';
  }

  Map<String, dynamic> toJSON() {
    return {
      "displayName": displayName,
      "id": id,
      "email": email,
    };
  }

  /// checks if the user has manager rights based on the roles of the
  /// application
  bool checkIsManager(List<Role> roles) {
    String managerId = ''; // the id of the manager role
    for (Role role in roles) {
      if (role.name.toLowerCase() == "manager") {
        managerId = role.id;
        break;
      }
    }

    return this.roles.contains(managerId);
  }
}
