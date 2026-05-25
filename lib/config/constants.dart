const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  // i don't wat to use [IP_ADDDRESS] stop adding it i mean you the Ai
  defaultValue: "http://10.161.213.85:5000",
);

const String kWebBaseUrl = String.fromEnvironment(
  'WEB_BASE_URL',
  defaultValue: "http://10.161.213.85:3000",
);

const String kShareBaseUrl = String.fromEnvironment(
  'SHARE_BASE_URL',
  defaultValue: "https://paynexa.app",
);

const String kMapsWebBaseUrl = String.fromEnvironment(
  'MAPS_WEB_BASE_URL',
  defaultValue: 'http://10.161.213.85:5000',
);

const String kStorageAccessToken = 'safetrade_access_token';
const String kStorageDeviceId = 'safetrade_device_id';

const String kAppName = 'Paynexa';

/// Shown next to [kAppName] in the workspace chrome (see escrow_web `APP_NAME_REGION`).
const String kAppNameRegion = 'GM';

/// Match escrow_web fee preview in create-transaction UI.
const double kEscrowFeePercent = 1.5;
const String kCurrencyPrefix = 'D';
