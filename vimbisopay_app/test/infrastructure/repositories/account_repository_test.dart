import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:http/http.dart' as http;
import 'account_repository_test.mocks.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
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

    // Setup default responses for database helper methods
    when(mockDatabaseHelper.getLedgerEntries(any))
        .thenAnswer((_) async => <LedgerEntry>[]);
    when(mockDatabaseHelper.getLatestLedgerTimestamp(any))
        .thenAnswer((_) async => DateTime.now());
    when(mockDatabaseHelper.saveLedgerEntries(any, any))
        .thenAnswer((_) async => {});
  });

  group('login', () {
    const tPhone = '+1234567890';
    const tPassword = 'password123';
    const tPasswordHash = 'hashedPassword';
    const tPasswordSalt = 'salt123';
    const tToken = 'testToken';

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

  group('getLedger and getLedgerLegacy', () {
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
          'ledger': [
            {
              'credexID': '123',
              'timestamp': '2024-01-01T00:00:00Z',
              'description': 'Test transaction',
              'amount': '100.00',
              'denomination': 'CXX',
              'counterpartyAccountName': 'Test Account',
            }
          ],
          'pagination': {'hasMore': false}
        }
      }
    };

    test('should return cached entries when available and no afterTimestamp provided', () async {
      // Arrange
      final cachedEntries = [
        LedgerEntry(
          credexID: '123',
          timestamp: DateTime.parse('2024-01-01T00:00:00Z'),
          type: 'CREDIT',
          amount: 100.0,
          denomination: 'CXX',
          description: 'Cached transaction',
          counterpartyAccountName: 'Test Account',
          formattedAmount: '100.00 CXX',
          accountId: '123',
          accountName: 'My Account',
        )
      ];

      when(mockDatabaseHelper.getUser()).thenAnswer((_) async => tUser);
      when(mockDatabaseHelper.getLedgerEntries('123'))
          .thenAnswer((_) async => cachedEntries);

      // Act
      final result = await repository.getLedger(accountId: '123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (entries) {
          expect(entries, equals(cachedEntries));
          expect(entries.length, equals(1));
          expect(entries.first.description, equals('Cached transaction'));
        },
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockDatabaseHelper.getLedgerEntries('123'));
      verifyNever(mockHttpClient.post(any, headers: any, body: any));
    });

    test('should fetch and cache new entries when afterTimestamp is provided', () async {
      // Arrange
      final afterTimestamp = DateTime.parse('2024-01-01T00:00:00Z');
      final cachedEntries = [
        LedgerEntry(
          credexID: '123',
          timestamp: afterTimestamp,
          type: 'CREDIT',
          amount: 100.0,
          denomination: 'CXX',
          description: 'Cached transaction',
          counterpartyAccountName: 'Test Account',
          formattedAmount: '100.00 CXX',
          accountId: '123',
          accountName: 'My Account',
        )
      ];

      when(mockDatabaseHelper.getUser()).thenAnswer((_) async => tUser);
      when(mockDatabaseHelper.getLedgerEntries('123'))
          .thenAnswer((_) async => cachedEntries);
      when(mockDatabaseHelper.getLatestLedgerTimestamp('123'))
          .thenAnswer((_) async => afterTimestamp);

      final expectedUrl = Uri.parse('${ApiConfig.baseUrl}/getLedger');
      final expectedHeaders = {
        'Content-Type': 'application/json',
        'x-client-api-key': ApiConfig.apiKey,
        'Authorization': 'Bearer ${tUser.token}',
      };
      final expectedBody = json.encode({
        'accountID': '123',
        'afterTimestamp': afterTimestamp.toIso8601String(),
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
        afterTimestamp: afterTimestamp,
      );

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (entries) {
          expect(entries.length, equals(2)); // 1 cached + 1 new
          expect(entries.first.credexID, equals('123')); // Most recent first
        },
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockDatabaseHelper.getLedgerEntries('123'));
      verify(mockDatabaseHelper.saveLedgerEntries(any, '123'));
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should fetch all entries when cache is empty', () async {
      // Arrange
      when(mockDatabaseHelper.getUser()).thenAnswer((_) async => tUser);
      when(mockDatabaseHelper.getLedgerEntries('123'))
          .thenAnswer((_) async => <LedgerEntry>[]);
      when(mockDatabaseHelper.getLatestLedgerTimestamp('123'))
          .thenAnswer((_) async => null);

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
        json.encode(tLedgerResponse),
        200,
      ));

      // Act
      final result = await repository.getLedger(accountId: '123');

      // Assert
      expect(result.isRight(), true);
      result.fold(
        (failure) => fail('Should not return failure'),
        (entries) {
          expect(entries.length, equals(1));
          expect(entries.first.credexID, equals('123'));
          expect(entries.first.description, equals('Test transaction'));
        },
      );

      verify(mockDatabaseHelper.getUser());
      verify(mockDatabaseHelper.getLedgerEntries('123'));
      verify(mockDatabaseHelper.getLatestLedgerTimestamp('123'));
      verify(mockDatabaseHelper.saveLedgerEntries(any, '123'));
      verify(mockHttpClient.post(
        expectedUrl,
        headers: expectedHeaders,
        body: expectedBody,
      ));
    });

    test('should return Map when getLedgerLegacy request is successful', () async {
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
      final result = await repository.getLedgerLegacy(
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

    test('should return failure when getLedger request fails', () async {
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
        'limit': 20,
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
      final result = await repository.getLedger(
        accountId: '123',
        limit: 20,
      );

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

    test('should return failure when getLedgerLegacy request fails', () async {
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
        json.encode({
          'message': 'Failed to get ledger',
        }),
        400,
      ));

      // Act
      final result = await repository.getLedgerLegacy(
        accountId: '123',
        startRow: 0,
        numRows: 10,
      );

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
