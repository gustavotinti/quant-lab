// Gera public/icons/icon-192.png a partir do icon-512.png (capturado do
// SVG via Chrome headless). Rodar da raiz do repo:
//   dart run apps/lab_cli/tool/make_icons.dart
import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const dir = 'public/icons';
  final src = img.decodePng(File('$dir/icon-512.png').readAsBytesSync());
  if (src == null) {
    stderr.writeln('icon-512.png não encontrado ou inválido');
    exit(1);
  }
  final small = img.copyResize(src,
      width: 192, height: 192, interpolation: img.Interpolation.cubic);
  File('$dir/icon-192.png').writeAsBytesSync(img.encodePng(small));
  stdout.writeln('icon-192.png gerado.');
}
