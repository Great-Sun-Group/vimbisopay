import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'account_repository_test.mocks.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/infrastructure/services/security_service.dart';
import 'package:vimbisopay_app/infrastructure/services/password_service.dart';
import 'package:vimbisopay_app/core/config/api_config.dart';

@GenerateMocks([
  http.Client,
  DatabaseHelper,
  SecurityService,
  PasswordService,
])
void main() {
  late AccountRepositoryImpl repository;
  late MockClient mockHttpClient;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockSecurityService mockSecurityService;
  late MockPasswordService mockPasswordService;

  setUp(() {
    mockHttpClient = MockClient();
    mockDatabaseHelper = MockDatabaseHelper();
    mockSecurityService = MockSecurityService();
    mockPasswordService = MockPasswordService();
    
    repository = AccountRepositoryImpl();
    repository.httpClient = mockHttpClient;
    repository.databaseHelper = mockDatabaseHelper;
    repository.securityService = mockSecurityService;
    repository.passwordService = mockPasswordService;
  });

  group('login', () {
    final tPhone = '+1234567890';
    final tPassword = 'password123';
    final tPasswordHash = 'hashedPassword';
    final tPasswordSalt = 'salt123';
    final tToken = 'testToken';

    final tLoginResponse = {
      'success': true,
      'message': 'Login successful',
      'data': {
        'action': {
          'details': {
            'memberID': '123',
            'phone': tPhone,
            'token': tToken,
          }
        },
        'dashboard': {
          'member': {
            'memberID': '123',
            'memberTier': 0,
            'firstname': 'John',
            'lastname': 'Doe',
            'memberHandle': 'johndoe',
            'defaultDenom': 'CXX'
          },
          'accounts': []
        }
      }
    };

    test('should return User when login is successful with password', () async {
      // Arrange
      when(mockPasswordService.hashPassword(any))
          .thenAnswer((_) async => (hash: tPasswordHash, salt: tPasswordSalt));
      
      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/login');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
      };
      final expectedBody = json.encode({
        'phone': tPhone,
        'password_hash': tPasswordHash,
        'password_salt': tPasswordSalt,
      });

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode(tLoginResponse),
        200,
      ));

      // Act
      final result = await repository.login(
        phone: tPhone,
        password: tPassword,
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) {
          expect(user.phone, equals(tPhone));
          expect(user.token, equals(tToken));
          expect(user.memberId, equals('123'));
          expect(user.passwordHash, equals(tPasswordHash));
          expect(user.passwordSalt, equals(tPasswordSalt));
        },
      );

      verify(mockPasswordService.hashPassword(tPassword));
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should return failure when login fails', () async {
      // Arrange
      when(mockPasswordService.hashPassword(any))
          .thenAnswer((_) async => (hash: tPasswordHash, salt: tPasswordSalt));
      
      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/login');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
      };
      final expectedBody = json.encode({
        'phone': tPhone,
        'password_hash': tPasswordHash,
        'password_salt': tPasswordSalt,
      });

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({
          'success': false,
          'message': 'Invalid credentials',
          'data': null
        }),
        401,
      ));

      // Act
      final result = await repository.login(
        phone: tPhone,
        password: tPassword,
      );

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<InfrastructureFailure>()),
        (_) => fail('Should not return success'),
      );

      verify(mockPasswordService.hashPassword(tPassword));
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });
  });

  group('getCurrentUser', () {
    final tUser = User(
      memberId: '123',
      phone: '+1234567890',
      token: 'testToken',
      passwordHash: 'hash',
      passwordSalt: 'salt',
      passwordChanged: DateTime.now(),
      dashboard: Dashboard.fromMap({
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX'
        },
        'accounts': []
      }),
    );

    test('should return User when user exists in database', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) => expect(user, equals(tUser)),
      );

      verify(mockDatabaseHelper.getUser());
    });

    test('should return null when no user exists in database', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => null);

      // Act
      final result = await repository.getCurrentUser();

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (user) => expect(user, isNull),
      );

      verify(mockDatabaseHelper.getUser());
    });
  });

  group('getLedger', () {
    final tUser = User(
      memberId: '123',
      phone: '+1234567890',
      token: 'testToken',
      passwordHash: 'hash',
      passwordSalt: 'salt',
      passwordChanged: DateTime.now(),
      dashboard: Dashboard.fromMap({
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX'
        },
        'accounts': []
      }),
    );

    final tLedgerResponse = {
      'data': {
        'dashboard': {
          'ledger': [],
          'pagination': {'hasMore': false}
        }
      }
    };

    test('should return ledger data when request is successful', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/getLedger');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({
        'accountID': '123',
        'startRow': 0,
        'numRows': 10,
      });

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode(tLedgerResponse),
        200,
      ));

      // Act
      final result = await repository.getLedger(
        accountId: '123',
        startRow: 0,
        numRows: 10,
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (data) => expect(data, equals(tLedgerResponse)),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should return failure when request fails', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/getLedger');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({
        'accountID': '123',
      });

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({
          'message': 'Failed to get ledger',
        }),
        400,
      ));

      // Act
      final result = await repository.getLedger(accountId: '123');

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<InfrastructureFailure>()),
        (_) => fail('Should not return success'),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });
  });

  group('createCredex', () {
    final tUser = User(
      memberId: '123',
      phone: '+1234567890',
      token: 'testToken',
      passwordHash: 'hash',
      passwordSalt: 'salt',
      passwordChanged: DateTime.now(),
      dashboard: Dashboard.fromMap({
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX'
        },
        'accounts': []
      }),
    );

    final tRequest = CredexRequest(
      issuerAccountID: '123',
      receiverAccountID: '456',
      denomination: 'CXX',
      initialAmount: 100,
      credexType: 'STANDARD',
      offersOrRequests: 'OFFERS',
      securedCredex: false,
    );

    final tResponse = {
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
            'defaultDenom': 'CXX'
          },
          'accounts': []
        }
      }
    };

    test('should return CredexResponse when request is successful', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/createCredex');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode(tRequest.toJson());

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode(tResponse),
        200,
      ));

      // Act
      final result = await repository.createCredex(tRequest);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (response) {
          expect(response.message, equals('Success'));
          expect(response.data.action.id, equals('123'));
          expect(response.data.action.type, equals('CREATE'));
        },
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should return failure when request fails', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/createCredex');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode(tRequest.toJson());

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({
          'message': 'Failed to create credex',
        }),
        400,
      ));

      // Act
      final result = await repository.createCredex(tRequest);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<InfrastructureFailure>()),
        (_) => fail('Should not return success'),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });
  });

  group('acceptCredexBulk', () {
    final tUser = User(
      memberId: '123',
      phone: '+1234567890',
      token: 'testToken',
      passwordHash: 'hash',
      passwordSalt: 'salt',
      passwordChanged: DateTime.now(),
      dashboard: Dashboard.fromMap({
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX'
        },
        'accounts': []
      }),
    );

    final credexIds = ['1', '2', '3'];

    test('should return true when request is successful', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/acceptCredexBulk');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({'credexIDs': credexIds});

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({'success': true}),
        200,
      ));

      // Act
      final result = await repository.acceptCredexBulk(credexIds);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (success) => expect(success, isTrue),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should return failure when request fails', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/acceptCredexBulk');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({'credexIDs': credexIds});

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({
          'message': 'Failed to accept credex',
        }),
        400,
      ));

      // Act
      final result = await repository.acceptCredexBulk(credexIds);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<InfrastructureFailure>()),
        (_) => fail('Should not return success'),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });
  });

  group('cancelCredex', () {
    final tUser = User(
      memberId: '123',
      phone: '+1234567890',
      token: 'testToken',
      passwordHash: 'hash',
      passwordSalt: 'salt',
      passwordChanged: DateTime.now(),
      dashboard: Dashboard.fromMap({
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX'
        },
        'accounts': []
      }),
    );

    final credexId = '123';

    test('should return true when request is successful', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/cancelCredex');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({'credexID': credexId});

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({'success': true}),
        200,
      ));

      // Act
      final result = await repository.cancelCredex(credexId);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (success) => expect(success, isTrue),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should return failure when request fails', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/cancelCredex');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({'credexID': credexId});

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({
          'message': 'Failed to cancel credex',
        }),
        400,
      ));

      // Act
      final result = await repository.cancelCredex(credexId);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<InfrastructureFailure>()),
        (_) => fail('Should not return success'),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });
  });

  group('registerNotificationToken', () {
    final tUser = User(
      memberId: '123',
      phone: '+1234567890',
      token: 'testToken',
      passwordHash: 'hash',
      passwordSalt: 'salt',
      passwordChanged: DateTime.now(),
      dashboard: Dashboard.fromMap({
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX'
        },
        'accounts': []
      }),
    );

    final fcmToken = 'test-fcm-token';

    test('should return true when request is successful', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/api/notifications/register-token');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({'token': fcmToken});

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({'success': true}),
        200,
      ));

      // Act
      final result = await repository.registerNotificationToken(fcmToken);

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (success) => expect(success, isTrue),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should return failure when request fails', () async {
      // Arrange
      when(mockDatabaseHelper.getUser())
          .thenAnswer((_) async => tUser);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/api/notifications/register-token');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({'token': fcmToken});

      when(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      )).thenAnswer((_) async => http.Response(
        json.encode({
          'message': 'Failed to register token',
        }),
        400,
      ));

      // Act
      final result = await repository.registerNotificationToken(fcmToken);

      // Assert
      expect(result.isLeft(), true);
      result.fold(
        (failure) => expect(failure, isA<InfrastructureFailure>()),
        (_) => fail('Should not return success'),
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });
  });
}
