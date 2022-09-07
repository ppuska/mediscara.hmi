/// Static class to store configuration data
class Config {
  static const industrial = 0;
  static const collaborative = 1;

  static int currentMode = -1;

  static void setMode(int mode) {
    currentMode = mode;
  }
}
