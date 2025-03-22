# Remote Config and App Updates API

This document provides specifications for the server-side API endpoints required to support remote configuration and app updates in the VimbisoPay app.

## Base URL

All API endpoints are relative to the base URL: `https://api.vimbisopay.com/v1`

## Authentication

All API endpoints require authentication using a bearer token in the Authorization header:

```
Authorization: Bearer <token>
```

## Endpoints

### 1. App Version Check

Checks if an update is available for the app.

**Endpoint:** `/api/v1/app/version-check`

**Method:** POST

**Request Body:**

```json
{
  "app_id": "com.vimbisopay.app",
  "current_version": "1.0.0",
  "device_info": {
    "android_version": "12",
    "device_model": "Pixel 6",
    "screen_size": "1080x2400"
  },
  "user_info": {
    "user_id": "user123"
  }
}
```

**Response:**

If an update is available:

```json
{
  "update_available": true,
  "latest_version": "1.1.0",
  "update_required": false,
  "update_priority": "medium",
  "update_type": "patch",
  "update_url": "https://downloads.vimbisopay.com/app/vimbisopay-1.1.0.apk",
  "file_size_bytes": 15728640,
  "release_notes": "Bug fixes and performance improvements",
  "release_date": "2025-03-15T00:00:00Z"
}
```

If no update is available:

```json
{
  "update_available": false
}
```

**Fields:**

- `update_available` (boolean): Whether an update is available
- `latest_version` (string): The latest version of the app
- `update_required` (boolean): Whether the update is required (forces the user to update)
- `update_priority` (string): The priority of the update (low, medium, high, critical)
- `update_type` (string): The type of update (patch, minor, major)
- `update_url` (string): The URL to download the update
- `file_size_bytes` (number): The size of the update file in bytes
- `release_notes` (string): Notes about the update
- `release_date` (string): The date the update was released (ISO 8601 format)

### 2. App Configuration

Fetches configuration for the app.

**Endpoint:** `/api/v1/app/config`

**Method:** POST

**Request Body:**

```json
{
  "app_id": "com.vimbisopay.app",
  "app_version": "1.0.0",
  "device_info": {
    "android_version": "12",
    "device_model": "Pixel 6",
    "screen_size": "1080x2400"
  },
  "user_id": "user123",
  "last_config_timestamp": 1647302400000
}
```

**Response:**

```json
{
  "config_timestamp": 1647388800000,
  "config_ttl_seconds": 3600,
  "feature_flags": {
    "enable_marketplace": true,
    "enable_push_notifications": true,
    "enable_biometric_auth": true
  },
  "remote_variables": {
    "api_endpoint": "https://api.vimbisopay.com/v2",
    "transaction_fee_percentage": 2.5,
    "max_transaction_amount": 10000,
    "min_transaction_amount": 100,
    "support_phone_number": "+1234567890",
    "support_email": "support@vimbisopay.com"
  },
  "user_specific_config": {
    "max_transaction_amount": 5000,
    "daily_transaction_limit": 10000,
    "monthly_transaction_limit": 100000
  },
  "ab_test_assignments": {
    "new_onboarding_flow": "variant_a",
    "payment_screen_redesign": "control"
  }
}
```

**Fields:**

- `config_timestamp` (number): The timestamp of the configuration (milliseconds since epoch)
- `config_ttl_seconds` (number): The time-to-live for the configuration in seconds
- `feature_flags` (object): Feature flags for the app
- `remote_variables` (object): Remote variables for the app
- `user_specific_config` (object): User-specific configuration
- `ab_test_assignments` (object): A/B test variant assignments

## Implementation Guidelines

### Version Check Logic

The server should implement the following logic for version checks:

1. Compare the client's `current_version` with the latest version available for the app.
2. If the client's version is older, return `update_available: true` along with the update information.
3. If the client's version is the latest, return `update_available: false`.
4. Set `update_required: true` for critical updates that should force the user to update.

### Configuration Logic

The server should implement the following logic for configuration:

1. If `last_config_timestamp` is provided and the configuration hasn't changed since then, return a 304 Not Modified response.
2. Otherwise, return the latest configuration.
3. Include user-specific configuration based on the `user_id`.
4. Assign A/B test variants based on the `user_id` and other factors.

## Error Handling

All API endpoints should return appropriate HTTP status codes and error messages:

- 200 OK: The request was successful
- 304 Not Modified: The configuration hasn't changed since the last request
- 400 Bad Request: The request was invalid
- 401 Unauthorized: Authentication failed
- 404 Not Found: The requested resource was not found
- 500 Internal Server Error: An error occurred on the server

Error responses should have the following format:

```json
{
  "error": {
    "code": "invalid_request",
    "message": "Invalid request parameters"
  }
}
```

## Rate Limiting

To prevent abuse, the API endpoints are rate-limited. The rate limits are as follows:

- Version Check: 10 requests per minute per device
- Configuration: 10 requests per minute per device

When a rate limit is exceeded, the API will return a 429 Too Many Requests response with a Retry-After header indicating how long to wait before making another request.

## Versioning

The API is versioned using the base URL. The current version is v1. When breaking changes are introduced, a new version will be created (e.g., v2).

## Testing

For testing purposes, the following test endpoints are available:

- `/api/v1/app/version-check/test`: Always returns an update is available
- `/api/v1/app/config/test`: Returns a test configuration

These endpoints do not require authentication and can be used for testing the client implementation.

## Changelog

### v1.0.0 (2025-03-20)

- Initial release of the Remote Config and App Updates API
