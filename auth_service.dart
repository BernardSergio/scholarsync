// lib/auth_service.dart

class User {
  final String username;
  final String passphrase;

  User(this.username, this.passphrase);
}

class AuthResult {
  final bool success;
  final User? user;
  final String? errorMessage;

  AuthResult(this.success, {this.user, this.errorMessage});
}

class AuthService {
  static const int _maxAttempts = 5;

  // Simulated user database: {username: User_object}
  final Map<String, User> _userDatabase = {
    'testuser': User('testuser', 'pass123'),
  };

  // Tracks failed login attempts: {username: attempt_count}
  final Map<String, int> _loginAttempts = {};

  Future<AuthResult> authenticate(String username, String passphrase) async {
    // Simulate a network delay
    await Future.delayed(const Duration(seconds: 1));

    // Check if the user is locked out
    if (_loginAttempts.containsKey(username) && _loginAttempts[username]! >= _maxAttempts) {
      return AuthResult(false, errorMessage: 'Account locked due to too many failed attempts.');
    }

    final user = _userDatabase[username];

    if (user != null && user.passphrase == passphrase) {
      // On success, reset attempts
      _loginAttempts.remove(username);
      return AuthResult(true, user: user);
    } else {
      // On failure, increment attempts
      final attempts = (_loginAttempts[username] ?? 0) + 1;
      _loginAttempts[username] = attempts;

      if (attempts >= _maxAttempts) {
        return AuthResult(false, errorMessage: 'Incorrect passphrase. Your account is now locked.');
      }
      final remaining = _maxAttempts - attempts;
      return AuthResult(false, errorMessage: 'Invalid username or passphrase. $remaining attempts remaining.');
    }
  }
}