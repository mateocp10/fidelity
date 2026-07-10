import 'dart:io';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Avatar circular del usuario que se renderiza IGUAL a cualquier tamaño
/// (rellena el contenedor que lo contiene). Al usarse como hijo del Hero y
/// como `flightShuttleBuilder`, la transición vuela como UNA sola pieza —
/// la foto o la inicial escalan suave con `FittedBox`, sin "rearmarse".
class UserAvatarCircle extends StatelessWidget {
  final String? avatarUrl;
  final File? newAvatarFile;

  const UserAvatarCircle({
    super.key,
    this.avatarUrl,
    this.newAvatarFile,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider? image;
    if (newAvatarFile != null) {
      image = FileImage(newAvatarFile!);
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      image = NetworkImage(avatarUrl!);
    }

    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentPurple.withValues(alpha: 0.1),
        image: image != null
            ? DecorationImage(image: image, fit: BoxFit.cover)
            : null,
      ),
      child: image == null
          ? LayoutBuilder(
              builder: (context, constraints) {
                // Ícono proporcional al tamaño del círculo (44px o 120px o el
                // tamaño intermedio durante el vuelo del Hero) → escala parejo.
                final side = constraints.biggest.shortestSide;
                final iconSize = side.isFinite && side > 0 ? side * 0.55 : 28.0;
                return Center(
                  child: Icon(
                    Icons.person_rounded,
                    size: iconSize,
                    color: AppTheme.accentPurple,
                  ),
                );
              },
            )
          : null,
    );
  }
}
