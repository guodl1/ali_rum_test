import 'dart:math';

bool isHitProbability(int probability) {
  if (probability < 0) {
    probability = 100;
  }
  int num = Random().nextInt(100) + 1; // [1,100]
  return num <= probability;
}
