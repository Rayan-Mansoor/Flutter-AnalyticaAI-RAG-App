import 'dart:math';

String generateRandomPassword({int length = 8}) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  Random random = Random();
  return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
}
