class MockApiResponses {
  static const loginSuccess = {
    'success': true,
    'message': 'Login successful',
    'data': {
      'memberId': '123',
      'phone': '+1234567890',
      'token': 'testToken',
      'password_hash': 'hashedPassword',
      'password_salt': 'salt123',
      'password_changed': 1704729600000, // 2024-01-08T12:00:00.000Z
      'dashboard': {
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX',
        },
        'accounts': [],
      },
    },
  };

  static const loginFailure = {
    'success': false,
    'message': 'Invalid credentials',
    'data': null,
  };

  static const emptyLedger = {
    'data': {
      'dashboard': {
        'ledger': [],
        'pagination': {'hasMore': false},
      },
    },
  };

  static const ledgerFailure = {
    'message': 'Failed to get ledger',
  };

  static const createCredexSuccess = {
    'message': 'Success',
    'data': {
      'action': {
        'id': '123',
        'type': 'CREATE',
        'timestamp': '2024-01-01T00:00:00Z',
        'actor': 'TEST',
        'details': {
          'amount': '100',
          'denomination': 'CXX',
          'securedCredex': false,
          'receiverAccountID': '456',
          'receiverAccountName': 'Test Account',
        },
      },
      'dashboard': {
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX',
        },
        'accounts': [],
      },
    },
  };

  static const createCredexFailure = {
    'message': 'Failed to create credex',
  };

  static const acceptCredexSuccess = {
    'success': true,
  };

  static const acceptCredexFailure = {
    'message': 'Failed to accept credex',
  };

  static const cancelCredexSuccess = {
    'success': true,
  };

  static const cancelCredexFailure = {
    'message': 'Failed to cancel credex',
  };

  static const registerTokenSuccess = {
    'success': true,
  };

  static const registerTokenFailure = {
    'message': 'Failed to register token',
  };
}
