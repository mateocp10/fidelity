import 'dart:io';
import 'package:image/image.dart';

void main() {
  final img1Bytes = File('assets/images/logo_transparente.png').readAsBytesSync();
  final img1 = decodeImage(img1Bytes)!;
  print('logo_transparente.png (FIDELITY LOGO 1) has transparency? ');
  
  final img2Bytes = File('assets/images/logo_blanco.png').readAsBytesSync();
  final img2 = decodeImage(img2Bytes)!;
  print('logo_blanco.png (FIDELITY LOGO 2) has transparency? ');
}
