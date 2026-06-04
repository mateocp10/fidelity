import 'dart:io';
import 'package:image/image.dart';

void main() {
  final img1Bytes = File('assets/images/logo_transparente.png').readAsBytesSync();
  final img1 = decodeImage(img1Bytes)!;
  bool img1HasAlpha = false;
  for (var p in img1) {
    if (p.a != 255) {
      img1HasAlpha = true;
      break;
    }
  }
  print('logo_transparente.png (1) alpha: ');
  
  final img2Bytes = File('assets/images/logo_blanco.png').readAsBytesSync();
  final img2 = decodeImage(img2Bytes)!;
  bool img2HasAlpha = false;
  for (var p in img2) {
    if (p.a != 255) {
      img2HasAlpha = true;
      break;
    }
  }
  print('logo_blanco.png (2) alpha: ');
}
