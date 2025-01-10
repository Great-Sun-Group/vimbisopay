import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:vimbisopay_app/application/usecases/accept_credex_bulk.dart';
import 'package:vimbisopay_app/core/error/failures.dart';
import 'package:vimbisopay_app/domain/entities/credex_request.dart';
import 'package:vimbisopay_app/domain/entities/credex_response.dart' as credex;
import 'package:vimbisopay_app/domain/entities/dashboard.dart';
import 'package:vimbisopay_app/domain/entities/user.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';

class MockAccountRepository extends Mock implements AccountRepository {}
class MockDatabaseHelper extends Mock implements DatabaseHelper {}
class MockAcceptCredexBulk extends Mock implements AcceptCredexBulk {}

void main() {
  late HomeBloc homeBloc;
  late MockAccountRepository mockRepository;
  late MockDatabaseHelper mockDatabaseHelper;
  late MockAcceptCredexBulk mockAcceptCredexBulk;
  late User mockUser;
  late credex.CredexResponse mockResponse;

  setUp(() {
    mockRepository = MockAccountRepository();
    mockDatabaseHelper = MockDatabaseHelper();
    mockAcceptCredexBulk = MockAcceptCredexBulk();
    
    // Create mock user
    mockUser = User(
      memberId: '123',
      phone: '+1234567890',
      token: 'testToken',
      passwordHash: 'hashedPassword',
      passwordSalt: 'salt123',
      passwordChanged: DateTime.now(),
      dashboard: Dashboard.fromMap({
        'member': {
          'memberID': '123',
          'memberTier': 0,
          'firstname': 'John',
          'lastname': 'Doe',
          'memberHandle': 'johndoe',
          'defaultDenom': 'CXX',
        },
        'accounts': [],
      }),
    );

    // Create mock response
    mockResponse = credex.CredexResponse(
      message: 'Success',
      data: credex.CredexData(
        action: credex.CredexAction(
          id: '123',
          type: 'CREATE',
          timestamp: DateTime.now().toIso8601String(),
          actor: 'TEST',
          details: credex.CredexActionDetails(
            amount: '100',
            denomination: 'CXX',
            securedCredex: false,
            receiverAccountID: '456',
            receiverAccountName: 'Test Account',
          ),
        ),
        dashboard: credex.CredexDashboard(
          member: credex.DashboardMember(
            memberID: '123',
            memberTier: 0,
            firstname: 'John',
            lastname: 'Doe',
            defaultDenom: 'CXX',
          ),
          accounts: [],
        ),
      ),
    );
    
    homeBloc = HomeBloc(
      accountRepository: mockRepository,
      acceptCredexBulk: mockAcceptCredexBulk,
    );
    homeBloc.databaseHelper = mockDatabaseHelper;

    // Register fallback values
    registerFallbackValue(mockUser);
    registerFallbackValue('test-string');
    registerFallbackValue(<String>['test-id']);
    registerFallbackValue(
      CredexRequest(
        issuerAccountID: 'test',
        receiverAccountID: 'test',
        denomination: 'CXX',
        initialAmount: 100,
        credexType: 'STANDARD',
        offersOrRequests: 'OFFERS',
        securedCredex: false,
      ),
    );

    // Default database mocks
    when(() => mockDatabaseHelper.getUser())
      .thenAnswer((_) async => mockUser);
    when(() => mockDatabaseHelper.saveUser(any()))
      .thenAnswer((_) async {});

    // Default repository mocks
    when(() => mockRepository.getLedger(
      accountId: any(named: 'accountId'),
      startRow: any(named: 'startRow'),
      numRows: any(named: 'numRows'),
    )).thenAnswer((_) async => const Right({'data': {'dashboard': {'ledger': [], 'pagination': {'hasMore': false}}}}));
  });

  tearDown(() async {
    await homeBloc.close();
  });

  test('initial state is correct', () {
    expect(homeBloc.state, const HomeState(status: HomeStatus.success));  // Intentionally wrong state
  });

  group('HomeCancelCredexStarted', () {
    test('cancels credex transaction successfully', () async {
      const credexId = '123';

      // Mock repository calls
      when(() => mockRepository.cancelCredex(credexId))
        .thenAnswer((_) async => const Right(true));
      when(() => mockRepository.login(
        phone: any(named: 'phone'),
        passwordHash: any(named: 'passwordHash'),
        passwordSalt: any(named: 'passwordSalt'),
      )).thenAnswer((_) async => Right(mockUser));

      homeBloc.add(const HomeCancelCredexStarted(credexId));

      await expectLater(
        homeBloc.stream,
        emitsInOrder([
          predicate<HomeState>((state) => 
            state.status == HomeStatus.cancellingCredex &&
            state.processingCredexIds.contains(credexId)
          ),
          predicate<HomeState>((state) => 
            state.status == HomeStatus.refreshing &&
            state.message == 'Refreshing balances...'
          ),
          predicate<HomeState>((state) => 
            state.status == HomeStatus.refreshing &&
            state.message == 'Updating balances...'
          ),
          predicate<HomeState>((state) => 
            state.status == HomeStatus.success &&
            state.dashboard != null
          ),
          predicate<HomeState>((state) => 
            state.status == HomeStatus.success &&
            state.message == 'Credex cancelled successfully' &&
            state.processingCredexIds.isEmpty
          ),
        ]),
      ).timeout(const Duration(seconds: 10));
    });

    test('handles cancel credex error', () async {
      const credexId = '123';

      when(() => mockRepository.cancelCredex(credexId))
        .thenAnswer((_) async => const Left(InfrastructureFailure('Failed to cancel credex')));

      homeBloc.add(const HomeCancelCredexStarted(credexId));

      await expectLater(
        homeBloc.stream,
        emitsInOrder([
          predicate<HomeState>((state) => state.status == HomeStatus.cancellingCredex),
          predicate<HomeState>((state) => state.status == HomeStatus.error && state.error != null),
        ]),
      ).timeout(const Duration(seconds: 10));
    });
  });

  group('HomeAcceptCredexBulkStarted', () {
    test('accepts credex transactions successfully', () async {
      const credexIds = ['123', '456'];
      
      // Mock usecase call
      when(() => mockAcceptCredexBulk.call(any()))
        .thenAnswer((_) async => const Right(true));

      // Mock repository calls
      when(() => mockRepository.login(
        phone: any(named: 'phone'),
        passwordHash: any(named: 'passwordHash'),
        passwordSalt: any(named: 'passwordSalt'),
      )).thenAnswer((_) async => Right(mockUser));

      homeBloc.add(const HomeAcceptCredexBulkStarted(credexIds));

      await expectLater(
        homeBloc.stream,
        emitsInOrder([
          predicate<HomeState>((state) => 
            state.status == HomeStatus.acceptingCredex &&
            credexIds.every((id) => state.processingCredexIds.contains(id))
          ),
          predicate<HomeState>((state) => 
            state.status == HomeStatus.refreshing &&
            state.message == 'Refreshing balances...'
          ),
          predicate<HomeState>((state) => 
            state.status == HomeStatus.refreshing &&
            state.message == 'Updating balances...'
          ),
          predicate<HomeState>((state) => 
            state.status == HomeStatus.success &&
            state.dashboard != null
          ),
        ]),
      ).timeout(const Duration(seconds: 10));
    });

    test('handles accept credex error', () async {
      const credexIds = ['123', '456'];
      
      when(() => mockAcceptCredexBulk.call(any()))
        .thenAnswer((_) async => const Left(InfrastructureFailure('Failed to accept')));

      homeBloc.add(const HomeAcceptCredexBulkStarted(credexIds));

      await expectLater(
        homeBloc.stream,
        emitsInOrder([
          predicate<HomeState>((state) => state.status == HomeStatus.acceptingCredex),
          predicate<HomeState>((state) => state.status == HomeStatus.error && state.error != null),
        ]),
      ).timeout(const Duration(seconds: 10));
    });
  });

  group('HomeRegisterNotificationToken', () {
    test('registers token successfully', () async {
      const token = 'test-token';
      
      when(() => mockRepository.registerNotificationToken(token))
        .thenAnswer((_) async => const Right(true));

      // Add event and wait for completion
      homeBloc.add(const HomeRegisterNotificationToken(token));
      
      // Wait for a small delay to allow the operation to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('handles registration error', () async {
      const token = 'test-token';
      
      when(() => mockRepository.registerNotificationToken(token))
        .thenAnswer((_) async => const Left(InfrastructureFailure('Failed to register token')));

      homeBloc.add(const HomeRegisterNotificationToken(token));

      await expectLater(
        homeBloc.stream,
        emits(
          predicate<HomeState>((state) => state.status == HomeStatus.error && state.error != null),
        ),
      ).timeout(const Duration(seconds: 10));
    });
  });

  group('CreateCredexEvent', () {
    test('creates credex successfully', () async {
      final request = CredexRequest(
        issuerAccountID: '123',
        receiverAccountID: '456',
        denomination: 'CXX',
        initialAmount: 100.0,
        credexType: 'STANDARD',
        offersOrRequests: 'OFFERS',
        securedCredex: false,
      );
      
      when(() => mockRepository.createCredex(any()))
        .thenAnswer((_) async => Right(mockResponse));

      // Add event and wait for completion
      homeBloc.add(CreateCredexEvent(request));
      
      // Wait for a small delay to allow the operation to complete
      await Future.delayed(const Duration(milliseconds: 100));
    });

    test('handles create credex error', () async {
      final request = CredexRequest(
        issuerAccountID: '123',
        receiverAccountID: '456',
        denomination: 'CXX',
        initialAmount: 100.0,
        credexType: 'STANDARD',
        offersOrRequests: 'OFFERS',
        securedCredex: false,
      );
      
      when(() => mockRepository.createCredex(any()))
        .thenAnswer((_) async => const Left(InfrastructureFailure('Failed to create credex')));

      homeBloc.add(CreateCredexEvent(request));

      await expectLater(
        homeBloc.stream,
        emits(
          predicate<HomeState>((state) => state.status == HomeStatus.error && state.error != null),
        ),
      ).timeout(const Duration(seconds: 10));
    });
  });
}
