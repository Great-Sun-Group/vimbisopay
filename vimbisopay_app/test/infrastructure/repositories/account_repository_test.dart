import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/ledger_entry.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import '../mocks/mock_repository.dart';

void main() {
  late AccountRepositoryImpl repository;
  late MockAccountRepository mockRepository;

  setUp(() {
    mockRepository = MockAccountRepository();
    repository = AccountRepositoryImpl();
  });

  group('getLedger', () {
    test('returns empty list when successful', () async {
      // Arrange
      mockRepository = MockAccountRepository(shouldSucceed: true);

      // Act
      final result = await mockRepository.getLedger(
        accountId: '123',
      );

      // Assert
      expect(result, isA<Right<Failure, List<LedgerEntry>>>());
      expect((result as Right).value, isEmpty);
    });

    test('returns failure when unsuccessful', () async {
      // Arrange
      mockRepository = MockAccountRepository(shouldSucceed: false);

      // Act
      final result = await mockRepository.getLedger(
        accountId: '123',
      );

      // Assert
      expect(result, isA<Left<Failure, List<LedgerEntry>>>());
      expect((result as Left).value, isA<InfrastructureFailure>());
    });
  });

  group('verifyOtp', () {
    test('returns true when successful', () async {
      // Arrange
      mockRepository = MockAccountRepository(shouldSucceed: true);

      // Act
      final result = await mockRepository.verifyOtp(
        token: 'token123',
        otp: '123456',
        memberId: 'member123',
      );

      // Assert
      expect(result, isA<Right<Failure, bool>>());
      expect((result as Right).value, isTrue);
    });

    test('returns failure when unsuccessful', () async {
      // Arrange
      mockRepository = MockAccountRepository(shouldSucceed: false);

      // Act
      final result = await mockRepository.verifyOtp(
        token: 'token123',
        otp: '123456',
        memberId: 'member123',
      );

      // Assert
      expect(result, isA<Left<Failure, bool>>());
      expect((result as Left).value, isA<InfrastructureFailure>());
    });
  });

  group('requestOtp', () {
    test('returns true when successful', () async {
      // Arrange
      mockRepository = MockAccountRepository(shouldSucceed: true);

      // Act
      final result = await mockRepository.requestOtp(
        phone: '+353834140208',
        purpose: 'PASSWORD_RESET',
      );

      // Assert
      expect(result, isA<Right<Failure, bool>>());
      expect((result as Right).value, isTrue);
    });

    test('returns failure when unsuccessful', () async {
      // Arrange
      mockRepository = MockAccountRepository(shouldSucceed: false);

      // Act
      final result = await mockRepository.requestOtp(
        phone: '+353834140208',
        purpose: 'PASSWORD_RESET',
      );

      // Assert
      expect(result, isA<Left<Failure, bool>>());
      expect((result as Left).value, isA<InfrastructureFailure>());
    });
  });
}
