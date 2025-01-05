# Technical Architecture

## System Components

### 1. Database Schema

#### Ad Space Management
```sql
CREATE TABLE ad_spaces (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    tier_level INTEGER NOT NULL,
    control_type VARCHAR(20) NOT NULL, -- 'platform', 'enhanced', 'user'
    algorithm_config JSONB,
    created_at TIMESTAMP NOT NULL,
    updated_at TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE ad_content (
    id UUID PRIMARY KEY,
    ad_space_id UUID NOT NULL,
    content_type VARCHAR(50) NOT NULL,
    content JSONB NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'active', 'pending', 'rejected'
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    created_at TIMESTAMP NOT NULL,
    FOREIGN KEY (ad_space_id) REFERENCES ad_spaces(id)
);

CREATE TABLE revenue_shares (
    id UUID PRIMARY KEY,
    ad_space_id UUID NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    user_share DECIMAL(10,2) NOT NULL,
    platform_share DECIMAL(10,2) NOT NULL,
    status VARCHAR(20) NOT NULL, -- 'pending', 'paid', 'failed'
    transaction_date TIMESTAMP NOT NULL,
    FOREIGN KEY (ad_space_id) REFERENCES ad_spaces(id)
);
```

### 2. API Endpoints

#### Ad Space Management
```typescript
// Ad Space Control
interface AdSpaceAPI {
  // Get ad space configuration
  GET /api/v1/ad-spaces/:userId
  Response: AdSpaceConfig

  // Update ad space settings
  PUT /api/v1/ad-spaces/:userId
  Body: {
    controlType: 'platform' | 'enhanced' | 'user'
    algorithmConfig?: AlgorithmConfig
  }

  // Get ad content
  GET /api/v1/ad-spaces/:userId/content
  Response: AdContent[]

  // Submit new ad content
  POST /api/v1/ad-spaces/:userId/content
  Body: {
    contentType: string
    content: object
    scheduling: {
      startTime?: string
      endTime?: string
    }
  }
}

// Revenue Management
interface RevenueAPI {
  // Get revenue statistics
  GET /api/v1/revenue/:userId
  Response: RevenueStats

  // Get payout history
  GET /api/v1/revenue/:userId/payouts
  Response: PayoutHistory[]

  // Request payout
  POST /api/v1/revenue/:userId/payouts
  Body: {
    amount: number
    paymentMethod: string
  }
}
```

### 3. Core Services

#### Ad Service
```typescript
class AdService {
  // Get appropriate ad for context
  async getAd(context: AdContext): Promise<Ad> {
    const userTier = await this.getTierLevel(context.userId);
    const adSpace = await this.getAdSpace(context.userId);
    
    if (userTier >= 5) { // Premium tier
      return this.getUserControlledAd(adSpace, context);
    } else if (userTier >= 1) { // Hustler tier
      return this.getEnhancedAd(adSpace, context);
    } else { // Free tier
      return this.getPlatformAd(context);
    }
  }

  // Handle ad interaction
  async trackInteraction(adId: string, type: InteractionType): Promise<void> {
    await this.analyticsService.trackEvent({
      type: 'ad_interaction',
      adId,
      interactionType: type,
      timestamp: new Date()
    });
  }
}
```

#### Revenue Service
```typescript
class RevenueService {
  // Calculate revenue share
  async calculateShare(
    amount: number,
    userId: string
  ): Promise<RevenueShare> {
    const tier = await this.getTierLevel(userId);
    let userShare = 0;
    
    switch(tier) {
      case 5: // Premium
        userShare = amount * 0.7;
        break;
      case 1: // Hustler
        userShare = amount * 0.1;
        break;
      default: // Free
        userShare = 0;
    }
    
    return {
      userShare,
      platformShare: amount - userShare
    };
  }

  // Process payout
  async processPayout(
    userId: string,
    amount: number
  ): Promise<PayoutResult> {
    // Validation
    await this.validatePayout(userId, amount);
    
    // Process payment
    const result = await this.paymentProcessor.execute({
      userId,
      amount,
      type: 'ad_revenue'
    });
    
    // Update records
    await this.updatePayoutRecords(userId, amount, result);
    
    return result;
  }
}
```

### 4. Frontend Components

#### Ad Display Widget
```dart
class AdSpaceWidget extends StatefulWidget {
  final String userId;
  final AdContext context;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdSpaceBloc, AdSpaceState>(
      builder: (context, state) {
        if (state is AdLoading) {
          return ShimmerLoadingWidget();
        }
        
        if (state is AdLoaded) {
          return AdContentWidget(
            ad: state.ad,
            onInteraction: (type) => 
              context.read<AdSpaceBloc>().add(
                AdInteractionEvent(type)
              )
          );
        }
        
        return Container(); // Fallback
      }
    );
  }
}
```

#### Revenue Dashboard
```dart
class RevenueDashboard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RevenueCubit, RevenueState>(
      builder: (context, state) {
        return Column(
          children: [
            RevenueStatsCard(
              totalEarned: state.totalEarned,
              pendingPayout: state.pendingPayout,
              lastPayout: state.lastPayout
            ),
            AdPerformanceChart(
              data: state.performanceData
            ),
            PayoutHistoryList(
              payouts: state.payoutHistory
            )
          ]
        );
      }
    );
  }
}
```

### 5. State Management

#### Ad Space Bloc
```dart
class AdSpaceBloc extends Bloc<AdSpaceEvent, AdSpaceState> {
  final AdService _adService;
  
  Stream<AdSpaceState> mapEventToState(AdSpaceEvent event) async* {
    if (event is LoadAd) {
      yield AdLoading();
      
      try {
        final ad = await _adService.getAd(event.context);
        yield AdLoaded(ad);
      } catch (e) {
        yield AdError(e.toString());
      }
    }
    
    if (event is AdInteraction) {
      await _adService.trackInteraction(
        event.adId,
        event.interactionType
      );
    }
  }
}
```

### 6. Integration Points

#### Kevel Integration
```typescript
class KevelAdServer implements AdServer {
  async getAd(context: AdContext): Promise<Ad> {
    const decision = await this.kevel.getDecisions({
      placements: [{
        divName: context.placement,
        adTypes: context.allowedTypes,
        properties: {
          userTier: context.userTier,
          location: context.location
        }
      }]
    });
    
    return this.mapDecisionToAd(decision);
  }
  
  async submitAd(content: AdContent): Promise<void> {
    await this.kevel.createCreative({
      title: content.title,
      body: content.body,
      imageUrl: content.imageUrl,
      clickUrl: content.clickUrl,
      properties: content.properties
    });
  }
}
```

### 7. Security Implementation

#### Authentication Middleware
```typescript
const adSpaceAuth = async (
  req: Request,
  res: Response,
  next: NextFunction
) => {
  const userId = req.params.userId;
  const token = req.headers.authorization;
  
  try {
    // Verify JWT
    const decoded = await verifyToken(token);
    
    // Check permissions
    const hasPermission = await checkAdSpacePermission(
      decoded.userId,
      userId
    );
    
    if (!hasPermission) {
      throw new Error('Unauthorized');
    }
    
    next();
  } catch (e) {
    res.status(401).json({
      error: 'Unauthorized access'
    });
  }
};
```

### 8. Analytics Implementation

#### Event Tracking
```typescript
interface AdEvent {
  type: 'impression' | 'click' | 'conversion';
  adId: string;
  userId: string;
  timestamp: Date;
  context: {
    placement: string;
    userTier: number;
    location: string;
  };
  metadata?: Record<string, any>;
}

class AnalyticsService {
  async trackEvent(event: AdEvent): Promise<void> {
    // Store event
    await this.eventStore.save(event);
    
    // Real-time processing
    await this.processRealTime(event);
    
    // Batch processing queue
    await this.batchQueue.add(event);
  }
  
  private async processRealTime(event: AdEvent): Promise<void> {
    // Update metrics
    await this.metricsService.increment(
      `ad_${event.type}`,
      1,
      {
        adId: event.adId,
        userId: event.userId,
        tier: event.context.userTier
      }
    );
    
    // Trigger alerts if needed
    await this.alertingService.check(event);
  }
}
```

### 9. Caching Strategy

#### Redis Cache Implementation
```typescript
class AdCache {
  private readonly redis: Redis;
  
  async getAd(key: string): Promise<Ad | null> {
    const cached = await this.redis.get(key);
    return cached ? JSON.parse(cached) : null;
  }
  
  async setAd(key: string, ad: Ad): Promise<void> {
    await this.redis.set(
      key,
      JSON.stringify(ad),
      'EX',
      300 // 5 minutes
    );
  }
  
  async invalidateAd(key: string): Promise<void> {
    await this.redis.del(key);
  }
}
```

### 10. Testing Strategy

#### Unit Tests
```typescript
describe('AdService', () => {
  let service: AdService;
  
  beforeEach(() => {
    service = new AdService(
      mockAdRepo,
      mockAnalytics,
      mockCache
    );
  });
  
  it('should return user-controlled ad for premium tier', async () => {
    const context = {
      userId: 'test-user',
      tier: 5,
      placement: 'feed'
    };
    
    const ad = await service.getAd(context);
    
    expect(ad.controlType).toBe('user');
  });
});
```

### 11. Monitoring Setup

#### Prometheus Metrics
```typescript
const adMetrics = {
  impressions: new Counter({
    name: 'ad_impressions_total',
    help: 'Total number of ad impressions',
    labelNames: ['tier', 'placement']
  }),
  
  loadTime: new Histogram({
    name: 'ad_load_time_seconds',
    help: 'Ad loading time in seconds',
    labelNames: ['tier', 'placement'],
    buckets: [0.1, 0.5, 1, 2, 5]
  }),
  
  revenue: new Counter({
    name: 'ad_revenue_total',
    help: 'Total ad revenue in cents',
    labelNames: ['tier', 'type']
  })
};
```

### 12. Deployment Configuration

#### Kubernetes Manifests
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ad-service
spec:
  replicas: 3
  selector:
    matchLabels:
      app: ad-service
  template:
    metadata:
      labels:
        app: ad-service
    spec:
      containers:
      - name: ad-service
        image: ad-service:1.0.0
        ports:
        - containerPort: 8080
        env:
        - name: KEVEL_API_KEY
          valueFrom:
            secretKeyRef:
              name: ad-service-secrets
              key: kevel-api-key
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
