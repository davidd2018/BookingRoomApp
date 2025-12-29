// Simple user session management
class UserSession {
  static String? _userEmail;

  static void setUserEmail(String email) {
    _userEmail = email.toLowerCase();
  }

  static String? getUserEmail() {
    return _userEmail;
  }

  static void clear() {
    _userEmail = null;
  }
}

