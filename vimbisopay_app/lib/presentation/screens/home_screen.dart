import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';
import 'package:vimbisopay_app/application/usecases/accept_credex_bulk.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/ui_utils.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';
import 'package:vimbisopay_app/presentation/widgets/account_card.dart';
import 'package:vimbisopay_app/presentation/widgets/home_action_buttons.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_animation.dart';
import 'package:vimbisopay_app/presentation/widgets/page_indicator.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';
import 'package:vimbisopay_app/presentation/widgets/member_tier_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late PageController _pageController;
  final ScrollController _scrollController = ScrollController();
  final AccountRepository _accountRepository = AccountRepositoryImpl();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  late HomeBloc _homeBloc;
  bool _isDisposed = false;
  bool _isInitializing = true;

  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('HomeScreen initialized');
    _pageController = PageController(initialPage: 0);
    _setupScrollListener();
    WidgetsBinding.instance.addObserver(this);
    _checkUserAndInitialize();
    _registerNotificationToken();
  }

  Future<void> _registerNotificationToken() async {
    try {
      final user = await _databaseHelper.getUser();
      if (user != null) {
        final messaging = FirebaseMessaging.instance;
        
        // Request permission for iOS
        if (Platform.isIOS) {
          await messaging.requestPermission();
        }
        
        final token = await messaging.getToken();
        if (token != null) {
          Logger.data('Got FCM token: $token');
          final success = await _notificationService.registerToken(token, user.token);
          
          if (success) {
            Logger.data('Successfully registered notification token');
          } else {
            Logger.error('Failed to register notification token');
          }
        }

        // Listen for token refresh
        messaging.onTokenRefresh.listen((newToken) {
          Logger.data('FCM token refreshed: $newToken');
          if (user.token != null) {
            _notificationService.registerToken(newToken, user.token);
          }
        });
      }
    } catch (e) {
      Logger.error('Error registering notification token', e);
    }
  }

  Future<void> _checkUserAndInitialize() async {
    try {
      final hasUser = await _databaseHelper.hasUser();
      if (!hasUser && mounted && !_isDisposed) {
        Logger.state('No user found, redirecting to login');
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }

      if (mounted && !_isDisposed) {
        setState(() {
          _isInitializing = false;
        });
        _initializeBloc();
      }
    } catch (e) {
      Logger.error('Error checking user existence', e);
      if (mounted && !_isDisposed) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  void _initializeBloc() {
    Logger.lifecycle('Initializing HomeBloc');
    _homeBloc = HomeBloc(
      acceptCredexBulk: AcceptCredexBulk(_accountRepository),
      accountRepository: _accountRepository,
    );
    // Trigger initial data load after a short delay to ensure navigation is complete
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_isDisposed) {
        _homeBloc.loadInitialData();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logger.lifecycle('App lifecycle state changed to: $state');
    if (state == AppLifecycleState.resumed && mounted && !_isDisposed) {
      Logger.lifecycle('App resumed - reinitializing bloc and refreshing data');
      _checkUserAndInitialize();
    }
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        Logger.interaction('Scroll threshold reached, loading more entries');
        _homeBloc.add(const HomeLoadMoreStarted());
      }
    });
  }

  @override
  void dispose() {
    Logger.lifecycle('HomeScreen disposing');
    _isDisposed = true;
    _pageController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    if (!_isInitializing) {
      _homeBloc.close();
    }
    super.dispose();
  }

  PreferredSize _buildAppBar(HomeState state) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(HomeConstants.appBarHeight),
      child: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        leadingWidth: 80,
        toolbarHeight: HomeConstants.appBarHeight,
        leading: _buildUserAvatar(state),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Logger.interaction('Settings button tapped');
                Navigator.pushNamed(context, '/settings');
              },
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(HomeState state) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        top: 16.0,
        bottom: 16.0,
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: HomeConstants.avatarSize / 2,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: state.dashboard != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person,
                        color: AppColors.primary,
                        size: HomeConstants.avatarSize / 2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        UIUtils.getInitials(
                          state.dashboard!.firstname,
                          state.dashboard!.lastname,
                        ),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: HomeConstants.captionTextSize,
                        ),
                      ),
                    ],
                  )
                : const Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                    size: HomeConstants.avatarSize / 2,
                  ),
          ),
          if (state.dashboard?.memberTier != null)
            Positioned(
              right: -8,
              bottom: -8,
              child: MemberTierBadge(
                tierType: state.dashboard!.memberTier.type,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(HomeState state) {
    return Column(
      children: [
        const SizedBox(height: HomeConstants.defaultPadding),
        ConstrainedBox(
          constraints: HomeConstants.getAccountCardConstraints(context),
          child: BlocListener<HomeBloc, HomeState>(
            listenWhen: (previous, current) => previous.currentPage != current.currentPage,
            listener: (context, state) {
              if (_pageController.page?.round() != state.currentPage) {
                _pageController.animateToPage(
                  state.currentPage,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                Logger.interaction('Account page changed to $index');
                _homeBloc.add(HomePageChanged(index));
              },
              itemCount: state.dashboard!.accounts.length,
              itemBuilder: (context, index) => AccountCard(
                account: state.dashboard!.accounts[index],
              ),
            ),
          ),
        ),
        if (state.dashboard!.accounts.length > 1)
          Padding(
            padding: const EdgeInsets.all(HomeConstants.defaultPadding),
            child: PageIndicator(
              count: state.dashboard!.accounts.length,
              currentPage: state.currentPage,
            ),
          ),
      ],
    );
  }

  Widget _buildScrollableContent(HomeState state) {
    return RefreshIndicator(
      onRefresh: () async {
        final completer = Completer<void>();
        
        // Create a subscription to listen for state changes
        late StreamSubscription<HomeState> subscription;
        subscription = _homeBloc.stream.listen(
          (state) {
            if (state.status == HomeStatus.success && !completer.isCompleted) {
              completer.complete();
              subscription.cancel();
            } else if (state.hasError && !completer.isCompleted) {
              completer.completeError(state.error!);
              subscription.cancel();
            }
          },
          onError: (error) {
            if (!completer.isCompleted) {
              completer.completeError(error);
              subscription.cancel();
            }
          },
          cancelOnError: false,
        );

        // Trigger the refresh
        _homeBloc.add(const HomeRefreshStarted());

        try {
          // Wait for completion
          await completer.future;
        } finally {
          // Ensure subscription is cancelled even if an error occurs
          subscription.cancel();
        }
      },
      color: AppColors.primary,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            if (state.dashboard != null) _buildAccountsSection(state),
            TransactionsList(
              key: ValueKey('transactions_${state.combinedLedgerEntries.length}_${state.accountLedgers.length}'),
            ),
            const SizedBox(height: kBottomNavigationBarHeight + 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: LoadingAnimation(size: 100),
        ),
      );
    }

    return BlocProvider(
      create: (context) => _homeBloc,
      child: BlocConsumer<HomeBloc, HomeState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.message != current.message ||
            previous.error != current.error,
        listener: (context, state) {
          // Clear any existing snackbars
          ScaffoldMessenger.of(context).clearSnackBars();

          // Handle success messages
          if (state.status == HomeStatus.success) {
            // Dismiss any loading dialogs first
            Navigator.of(context).popUntil((route) => route.isFirst);
            
            if (state.message != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message!),
                  backgroundColor: AppColors.success,
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'DISMISS',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
                ),
              );
            }
          }

          // Handle error messages
          if (state.hasError && state.error != null) {
            // Dismiss any loading dialogs first
            Navigator.of(context).popUntil((route) => route.isFirst);
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: AppColors.error,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 5),
                action: SnackBarAction(
                  label: 'DISMISS',
                  textColor: Colors.white,
                  onPressed: () {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  },
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          // Show loading only if we don't have dashboard data yet
          if (state.status == HomeStatus.loading && state.dashboard == null) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: LoadingAnimation(size: 100),
              ),
            );
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: _buildAppBar(state),
            body: SafeArea(
              child: _buildScrollableContent(state),
            ),
            bottomNavigationBar: HomeActionButtons(
              accounts: state.dashboard?.accounts,
              accountRepository: _accountRepository,
              homeBloc: _homeBloc,
              databaseHelper: _databaseHelper,
            ),
          );
        },
      ),
    );
  }
}
