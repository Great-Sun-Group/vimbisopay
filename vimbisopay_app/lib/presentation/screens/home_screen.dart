import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import 'package:vimbisopay_app/application/usecases/accept_credex_bulk.dart';
import 'package:vimbisopay_app/application/usecases/accept_credex.dart';
import 'package:vimbisopay_app/application/usecases/upgrade_member_tier.dart';
import 'package:vimbisopay_app/presentation/widgets/upgrade_tier_bottom_sheet.dart';
import 'package:vimbisopay_app/core/theme/app_colors.dart';
import 'package:vimbisopay_app/core/utils/logger.dart';
import 'package:vimbisopay_app/core/utils/ui_utils.dart';
import 'package:vimbisopay_app/domain/repositories/account_repository.dart';
import 'package:vimbisopay_app/domain/entities/dashboard.dart' show Dashboard, MemberTierType;
import 'package:vimbisopay_app/infrastructure/repositories/account_repository_impl.dart';
import 'package:vimbisopay_app/infrastructure/database/database_helper.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_bloc.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_event.dart';
import 'package:vimbisopay_app/presentation/blocs/home/home_state.dart';
import 'package:vimbisopay_app/presentation/constants/home_constants.dart';
import 'package:vimbisopay_app/presentation/widgets/account_card.dart';
import 'package:vimbisopay_app/presentation/widgets/home_action_buttons.dart';
import 'package:vimbisopay_app/presentation/widgets/loading_dialog.dart';
import 'package:vimbisopay_app/presentation/widgets/page_indicator.dart';
import 'package:vimbisopay_app/presentation/widgets/transactions_list.dart';
import 'package:vimbisopay_app/infrastructure/services/notification_service.dart';
import 'package:vimbisopay_app/infrastructure/services/service_locator.dart';
import 'package:vimbisopay_app/infrastructure/services/analytics_service.dart';

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
  late AnalyticsService _analyticsService;
  StreamSubscription? _refreshSubscription;
  StreamSubscription? _notificationSubscription;

  void _showUpgradeBottomSheet(BuildContext context, String accountId) {
    // Track button tap for upgrade
    try {
      _analyticsService.trackButtonTap(
        'upgrade_tier_button',
        screenName: 'HomeScreen',
        parameters: {'account_id': accountId},
      );
    } catch (e) {
      Logger.error('Failed to track upgrade button tap', e);
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      builder: (context) => BlocProvider.value(
        value: _homeBloc,
        child: BlocListener<HomeBloc, HomeState>(
          listenWhen: (previous, current) => 
            previous.status != current.status && 
            (current.status == HomeStatus.upgradingTier || 
             current.status == HomeStatus.success || 
             current.status == HomeStatus.error),
          listener: (context, state) {
            if (state.status == HomeStatus.upgradingTier) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const LoadingDialog(
                  message: 'Upgrading your account...',
                ),
              );
            } else if (state.status == HomeStatus.success || state.status == HomeStatus.error) {
              try {
                // Safely pop dialogs by wrapping in try-catch
                // First try to pop the loading dialog
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
                
                // Then try to pop the bottom sheet
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                Logger.error('Error while popping dialogs', e);
                // If we can't pop normally, use a more aggressive approach
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }
          },
          child: UpgradeTierBottomSheet(
            onConfirm: () {
              // Track confirm button tap
              try {
                _analyticsService.trackButtonTap(
                  'confirm_upgrade_button',
                  screenName: 'UpgradeTierBottomSheet',
                  parameters: {'account_id': accountId},
                );
              } catch (e) {
                Logger.error('Failed to track confirm upgrade button tap', e);
              }
              
              _homeBloc.add(HomeUpgradeTierStarted(accountId));
            },
            onCancel: () {
              // Track cancel button tap
              try {
                _analyticsService.trackButtonTap(
                  'cancel_upgrade_button',
                  screenName: 'UpgradeTierBottomSheet',
                );
              } catch (e) {
                Logger.error('Failed to track cancel upgrade button tap', e);
              }
              
              Navigator.pop(context);
            },
            isLoading: _homeBloc.state.status == HomeStatus.upgradingTier,
          ),
        ),
      ),
    );
  }

  Future<void> _setupNotificationListeners() async {
    if (!mounted || _isDisposed) {
      Logger.error('Cannot setup listeners - widget is disposed or unmounted');
      return;
    }

    Logger.data('Setting up notification listeners');
    
    try {
      // Cancel any existing subscriptions
      await _refreshSubscription?.cancel();
      await _notificationSubscription?.cancel();
      _refreshSubscription = null;
      _notificationSubscription = null;

      final initialized = await _notificationService.initialize();
      if (!initialized) {
        Logger.error('Failed to initialize NotificationService');
        return;
      }

      if (!mounted || _isDisposed) {
        Logger.error('Widget disposed during initialization');
        return;
      }

      // Listen for refresh events
      Logger.data('Setting up refresh subscription');
      _refreshSubscription = _notificationService.onRefreshNeeded.listen(
        (_) {
          Logger.data('''
Refresh triggered by notification:
- Is disposed: $_isDisposed
- Is mounted: $mounted
- Has HomeBloc: ${_homeBloc != null}
''');
          if (!_isDisposed && mounted) {
            Logger.data('Triggering HomeRefreshStarted event');
            _homeBloc.add(const HomeRefreshStarted());
          } else {
            Logger.error('Cannot refresh - widget is disposed or unmounted');
          }
        },
        onError: (error, stackTrace) {
          Logger.error('''
Error in refresh subscription:
- Error: $error
- Stack trace: $stackTrace
''');
        },
      );
      Logger.data('Refresh subscription setup complete');

      // Listen for notifications to show SnackBar
      Logger.data('Setting up notification subscription');
      _notificationSubscription = _notificationService.onNotification.listen(
        (message) {
          if (!_isDisposed && mounted) {
            Logger.data('Showing notification SnackBar');
            
            // Clear any existing SnackBars first
            try {
              ScaffoldMessenger.of(context).clearSnackBars();
            } catch (e) {
              Logger.error('Error clearing snackbars', e);
            }
            
            final notificationType = message.data['type']?.toUpperCase();
            Logger.data('Processing notification type: $notificationType');
            
            // Handle OFFER_ACCEPTED notification
            if (notificationType == 'OFFER_ACCEPTED') {
              final credexId = message.data['credexID'];
              if (credexId != null) {
                Logger.data('Received OFFER_ACCEPTED for credexId: $credexId');
                _homeBloc.add(HomeOfferAccepted(credexId));
                
                // Use post-frame callback to ensure widget tree is stable
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    try {
                      // Show status change snackbar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle,
                                  color: AppColors.white,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (message.notification?.title != null)
                                        Text(
                                          message.notification!.title!,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                      if (message.notification?.body != null)
                                        Text(
                                          message.notification!.body!,
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          backgroundColor: AppColors.success,
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 4),
                          margin: const EdgeInsets.all(8),
                          elevation: 6,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      );
                    } catch (e) {
                      Logger.error('Error showing OFFER_ACCEPTED snackbar', e);
                    }
                  }
                });
                return;
              }
            }
            
            // Special handling for OFFER_CREATED
            if (notificationType == 'OFFER_CREATED') {
              Logger.data('Showing OFFER_CREATED notification');
              
              // Use post-frame callback to ensure widget tree is stable
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                            children: [
                              Transform.rotate(
                                angle: 180 * (3.14159 / 180), // Rotate 180 degrees to show incoming
                                child: const Icon(
                                  Icons.payments,
                                  color: AppColors.white,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'New Incoming Offer',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    if (message.notification?.body != null)
                                      Text(
                                        message.notification!.body!,
                                        style: const TextStyle(
                                          color: AppColors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 4),
                        margin: const EdgeInsets.all(8),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        action: SnackBarAction(
                          label: 'DISMISS',
                          textColor: AppColors.white,
                          onPressed: () {
                            if (mounted) {
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            }
                          },
                        ),
                      ),
                    );
                  } catch (e) {
                    Logger.error('Error showing OFFER_CREATED snackbar', e);
                  }
                }
              });
              return;
            }

            // Default notification handling for other types
            Logger.data('Showing default notification');
            
            // Use post-frame callback to ensure widget tree is stable
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (message.notification?.title != null)
                              Text(
                                message.notification!.title!,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.white,
                                  fontSize: 16,
                                ),
                              ),
                            if (message.notification?.title != null && message.notification?.body != null)
                              const SizedBox(height: 4),
                            if (message.notification?.body != null)
                              Text(
                                message.notification!.body!,
                                style: const TextStyle(
                                  color: AppColors.white,
                                  fontSize: 14,
                                ),
                              ),
                          ],
                        ),
                      ),
                      backgroundColor: AppColors.primary,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                      margin: const EdgeInsets.all(8),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      action: SnackBarAction(
                        label: 'DISMISS',
                        textColor: AppColors.white,
                        onPressed: () {
                          if (mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          }
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  Logger.error('Error showing default notification snackbar', e);
                }
              }
            });
          }
        },
        onError: (error, stackTrace) {
          Logger.error('''
Error in notification subscription:
- Error: $error
- Stack trace: $stackTrace
''');
        },
      );
      Logger.data('''
Notification listeners setup complete:
- Refresh subscription active: ${_refreshSubscription != null}
- Notification subscription active: ${_notificationSubscription != null}
''');
    } catch (e, stackTrace) {
      Logger.error('''
Error setting up notification listeners:
- Error: $e
- Stack trace: $stackTrace
''');
    }
  }

  void _initializeBloc() {
    Logger.lifecycle('Initializing HomeBloc');
    _homeBloc = HomeBloc(
      accountRepository: _accountRepository,
      databaseHelper: _databaseHelper,
      acceptCredexBulk: AcceptCredexBulk(_accountRepository),
      acceptCredex: AcceptCredex(_accountRepository),
      upgradeMemberTier: UpgradeMemberTier(_accountRepository),
    );
    
    // Use addPostFrameCallback to ensure widget is fully mounted
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_isDisposed && mounted) {
        _homeBloc.loadInitialData();
        await _setupNotificationListeners();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    Logger.lifecycle('HomeScreen initialized');
    _pageController = PageController(initialPage: 0);
    _setupScrollListener();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize analytics service
    try {
      _analyticsService = ServiceLocator.analyticsService;
      // Track screen view
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _analyticsService.trackScreenView('HomeScreen');
      });
    } catch (e) {
      Logger.error('Failed to initialize analytics service', e);
    }
    
    _checkUserAndInitialize();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.9) {
        
        // Cancel existing timer if any
        _scrollDebounceTimer?.cancel();
        
        // Set new timer
        _scrollDebounceTimer = Timer(const Duration(milliseconds: 500), () {
          if (mounted && !_isDisposed) {
            Logger.interaction('Scroll threshold reached, loading more entries');
            _homeBloc.add(const HomeLoadMoreStarted());
          }
        });
      }
    });
  }

  Timer? _scrollDebounceTimer;

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    Logger.lifecycle('App lifecycle state changed to: $state');
    if (state == AppLifecycleState.resumed && mounted && !_isDisposed) {
      Logger.lifecycle('App resumed - reinitializing services');
      
      // First check if we need to reinitialize the bloc
      _checkUserAndInitialize();
      
      // Then reinitialize notification listeners
      Logger.lifecycle('Reinitializing notification listeners');
      _setupNotificationListeners().then((_) {
        Logger.lifecycle('Notification listeners reinitialized');
        
        // Trigger a refresh to ensure data is up to date, but mark it as foreground
        // to allow the bloc to optimize the refresh behavior
        if (mounted && !_isDisposed) {
          Logger.lifecycle('Triggering HomeRefreshStarted event with foreground source');
          _homeBloc.add(const HomeRefreshStarted(source: RefreshSource.foreground));
        }
      }).catchError((error, stackTrace) {
        Logger.error('''
Error reinitializing notification listeners:
- Error: $error
- Stack trace: $stackTrace
''');
      });
    } else if (state == AppLifecycleState.paused) {
      Logger.lifecycle('App paused - cleaning up notification subscriptions');
      _refreshSubscription?.cancel();
      _notificationSubscription?.cancel();
      _refreshSubscription = null;
      _notificationSubscription = null;
    }
  }

  @override
  void dispose() {
    Logger.lifecycle('HomeScreen disposing');
    _isDisposed = true;
    _pageController.dispose();
    _scrollController.dispose();
    _scrollDebounceTimer?.cancel();
    _refreshSubscription?.cancel();
    _notificationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    // Don't close the HomeBloc here as it needs to stay alive for notifications
    super.dispose();
  }

  Widget _buildUserAvatar(HomeState state) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16.0,
        top: 16.0,
        bottom: 16.0,
      ),
      child: CircleAvatar(
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
    );
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
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search transactions...',
              hintStyle: TextStyle(color: AppColors.textPrimary.withOpacity(0.5)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
              prefixIcon: const Icon(Icons.search, color: AppColors.primary),
              suffixIcon: (state.searchQuery.isNotEmpty ||
                      state.filteredLedgerEntries != state.combinedLedgerEntries ||
                      state.filteredPendingInTransactions != state.pendingInTransactions ||
                      state.filteredPendingOutTransactions != state.pendingOutTransactions)
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.primary),
                      onPressed: () {
                        Logger.interaction('Search cleared');
                        
                        // Track search clear button tap
                        try {
                          _analyticsService.trackButtonTap(
                            'search_clear_button',
                            screenName: 'HomeScreen',
                          );
                        } catch (e) {
                          Logger.error('Failed to track search clear button tap', e);
                        }
                        
                        _homeBloc.add(const HomeSearchStarted(''));
                      },
                    )
                  : null,
            ),
            style: const TextStyle(color: AppColors.textPrimary),
            onChanged: (query) {
              Logger.interaction('Search query changed: $query');
              
              // Track search query change
              if (query.isNotEmpty) {
                try {
                  _analyticsService.trackCustomEvent(
                    'search_query_changed',
                    parameters: {'query': query},
                  );
                } catch (e) {
                  Logger.error('Failed to track search query change', e);
                }
              }
              
              _homeBloc.add(HomeSearchStarted(query));
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Logger.interaction('Settings button tapped');
                
                // Track settings button tap
                try {
                  _analyticsService.trackButtonTap(
                    'settings_button',
                    screenName: 'HomeScreen',
                  );
                } catch (e) {
                  Logger.error('Failed to track settings button tap', e);
                }
                
                Navigator.pushNamed(context, '/settings');
              },
              tooltip: 'Settings',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSection(HomeState state) {
    return Column(
      children: [
        const SizedBox(height: HomeConstants.smallPadding), // Reduced from defaultPadding
        ConstrainedBox(
          constraints: HomeConstants.getAccountCardConstraints(context),
          child: BlocConsumer<HomeBloc, HomeState>(
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
            buildWhen: (previous, current) {
              // Check if any account balances have changed
              final previousBalances = previous.dashboard?.accounts
                  .map((a) => a.balanceData.netCredexAssetsInDefaultDenom)
                  .join('_');
              final currentBalances = current.dashboard?.accounts
                  .map((a) => a.balanceData.netCredexAssetsInDefaultDenom)
                  .join('_');
                  
              return previous.dashboard != current.dashboard || 
                     previous.currentPage != current.currentPage ||
                     previousBalances != currentBalances;
            },
            builder: (context, state) {
              // Create a key that changes when any account's balance changes
              final balancesKey = state.dashboard!.accounts
                  .map((a) => a.balanceData.netCredexAssetsInDefaultDenom)
                  .join('_');
                  
              return PageView.builder(
                key: ValueKey('accounts_pageview_$balancesKey'),
                controller: _pageController,
                onPageChanged: (index) {
                  Logger.interaction('Account page changed to $index');
                  
                  // Track account page change
                  try {
                    _analyticsService.trackCustomEvent(
                      'account_page_changed',
                      parameters: {
                        'page_index': index,
                        'account_id': state.dashboard!.accounts[index].accountID,
                      },
                    );
                  } catch (e) {
                    Logger.error('Failed to track account page change', e);
                  }
                  
                  _homeBloc.add(HomePageChanged(index));
                },
                itemCount: state.dashboard!.accounts.length,
                itemBuilder: (context, index) => AccountCard(
                  key: ValueKey('account_card_${state.dashboard!.accounts[index].accountID}_${state.dashboard!.accounts[index].balanceData.netCredexAssetsInDefaultDenom}'),
                  account: state.dashboard!.accounts[index],
                  memberTier: state.dashboard!.memberTier,
                  onUpgrade: state.dashboard!.memberTier.type == MemberTierType.open
                      ? () => _showUpgradeBottomSheet(
                          context, state.dashboard!.accounts[index].accountID)
                      : null,
                ),
              );
            },
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

        // Trigger the refresh with userAction source to bypass throttling
        _homeBloc.add(const HomeRefreshStarted(source: RefreshSource.userAction, forceRefresh: true));

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
            
            // Add loading indicator below accounts section when refreshing
            if (state.isRefreshing)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InlineLoadingAnimation(size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Refreshing your dashboard...',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              
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
          child: InlineLoadingAnimation(size: 80),
        ),
      );
    }

    return BlocProvider.value(
      value: _homeBloc,
      child: BlocConsumer<HomeBloc, HomeState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.message != current.message ||
            previous.error != current.error,
        listener: (context, state) {
          // Clear any existing snackbars if mounted
          if (mounted) {
            try {
              ScaffoldMessenger.of(context).clearSnackBars();
            } catch (e) {
              Logger.error('Error clearing snackbars', e);
            }
          }

          // Show message if present, regardless of status
          if (state.message != null && mounted) {
            Logger.data('Showing snackbar with message: ${state.message}');
            
            // Use post-frame callback to ensure widget tree is stable
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  // Ensure any existing snackbar is removed first
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  
                  // Show the new snackbar
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.message!,
                        style: state.status == HomeStatus.error 
                            ? const TextStyle(color: AppColors.lightCream)
                            : null,
                      ),
                      backgroundColor: state.status == HomeStatus.error 
                          ? AppColors.error 
                          : AppColors.success,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'DISMISS',
                        textColor: state.status == HomeStatus.error 
                            ? AppColors.lightCream
                            : AppColors.white,
                        onPressed: () {
                          if (mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          }
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  Logger.error('Error showing message snackbar', e);
                }
              }
            });
          }

          // Handle error messages
          if (state.hasError && state.error != null) {
            // Dismiss any loading dialogs first
            try {
              Navigator.of(context).popUntil((route) => route.isFirst);
            } catch (e) {
              Logger.error('Error popping dialogs', e);
            }
            
            // Log the error for debugging
            Logger.error('Error occurred', state.error);
            
            // Use post-frame callback to ensure widget tree is stable
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                try {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        state.error!,
                        style: const TextStyle(color: AppColors.lightCream),
                      ),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'DISMISS',
                        textColor: AppColors.lightCream,
                        onPressed: () {
                          if (mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          }
                        },
                      ),
                    ),
                  );
                } catch (e) {
                  Logger.error('Error showing error snackbar', e);
                }
              }
            });
          }
        },
        builder: (context, state) {
          // Show loading only if we don't have dashboard data yet
          if (state.status == HomeStatus.loading && state.dashboard == null) {
            return const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: InlineLoadingAnimation(size: 80),
              ),
            );
          }

          return Scaffold(
            backgroundColor: AppColors.transparent,
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
