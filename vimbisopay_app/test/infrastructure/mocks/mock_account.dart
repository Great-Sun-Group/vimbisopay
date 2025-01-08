import 'package:vimbisopay_app/domain/entities/account.dart';

class MockAccount extends Account {
  MockAccount({
    required String id,
    required String name,
    required String handle,
    required String defaultDenom,
    required Map<String, double> balances,
  }) : super(
          id: id,
          name: name,
          handle: handle,
          defaultDenom: defaultDenom,
          balances: balances,
        );

  factory MockAccount.standard() {
    return MockAccount(
      id: '123',
      name: 'Test Account',
      handle: 'test_account',
      defaultDenom: 'CXX',
      balances: {'CXX': 100.0},
    );
  }
}
