import 'package:flutter/material.dart';

class ProfilePicture {
  const ProfilePicture(
      {required this.id, required this.label, required this.color});

  final String id;
  final String label;
  final Color color;
}

const profilePictures = <ProfilePicture>[
  ProfilePicture(id: 'disc', label: 'Disc', color: Color(0xFFE53935)),
  ProfilePicture(id: 'slab', label: 'Slab', color: Color(0xFFFB8C00)),
  ProfilePicture(id: 'wedge', label: 'Wedge', color: Color(0xFF43A047)),
  ProfilePicture(id: 'arch', label: 'Arch', color: Color(0xFF1E88E5)),
  ProfilePicture(id: 'loop', label: 'Loop', color: Color(0xFF8E24AA)),
];

ProfilePicture pictureById(String id) {
  for (final picture in profilePictures) {
    if (picture.id == id) return picture;
  }
  return profilePictures.first;
}
