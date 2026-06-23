const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // i don't wat to use [IP_ADDDRESS] stop adding it i mean you the Ai
  defaultValue: "https://paynexa-api-gateway-production.up.railway.app",
  // defaultValue: "http://10.34.107.168:5000 ",
);

const String kWebBaseUrl = String.fromEnvironment(
  'WEB_BASE_URL',
  defaultValue: "https://paynexa-web-work
  space.vercel.app",
);

const String kShareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: "https://paynexa-web-workspace.vercel.app",
);

const String kMapsWebBaseUrl = String.fromEnvironment(
  'MAPS_WEB_BASE_URL',
  defaultValue: 'https://paynexa-web-workspace.vercel.app',
);

const String kStorageAccessToken = 'paynexa_access_token';
const String kStorageDeviceId = 'paynexa_device_id';

/// Legacy keys kept for one-time migration from SafeTrade branding.
const String kLegacyStorageAccessToken = 'safetrade_access_token';
const String kLegacyStorageDeviceId = 'safetrade_device_id';

const String kAppName = 'PayNexa';

/// Custom URL scheme for deep links back into the mobile app after external checkout.
const String kDeepLinkScheme = 'paynexa';

/// Shown next to [kAppName] in the workspace chrome (see escrow_web `APP_NAME_REGION`).
const String kAppNameRegion = '';

/// Match escrow_web fee preview in create-transaction UI.
const double kEscrowFeePercent = 1.5;
const String kCurrencyPrefix = 'D';
const String stripePublishableKey = 'pk_test_51TPkmO2M0GJI83ntHiwicPxaxo1Ep6KV9nMMfw7qGUjPRZK88REXpuKzmlngcKujgI5qIZda6YaNT4hzCupn9UiL00dqJp7hsZ';