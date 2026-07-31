window.QR_MENU_CONFIG = {
  projectId: 'REPLACE_WITH_FIREBASE_PROJECT_ID',
  apiKey: 'REPLACE_WITH_FIREBASE_WEB_API_KEY',
  // Public menu JSON (Cloud Function) — browser API key kısıtına takılmaz
  menuUrl:
    'https://us-central1-REPLACE_WITH_FIREBASE_PROJECT_ID.cloudfunctions.net/getQrMenuPublic',
  requestUrl:
    'https://us-central1-REPLACE_WITH_FIREBASE_PROJECT_ID.cloudfunctions.net/createTableServiceRequest',
  defaultBranchId: 'branch_1',
};
