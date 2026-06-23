# Firebase production kurulumu (Windows) — tostusahane-e4e71
# Console: https://console.firebase.google.com/project/tostusahane-e4e71/overview

# 1) Firebase CLI ile oturum açın (henüz yapılmadıysa)
npx -y firebase-tools@latest login

# 2) Proje seçimi (.firebaserc zaten default: tostusahane-e4e71)
npx -y firebase-tools@latest use tostusahane-e4e71

# 3) FlutterFire ile platform config üretin (zaten yapıldıysa atlayın)
dart pub global activate flutterfire_cli
flutterfire configure --project=tostusahane-e4e71 --platforms=android,ios,web --yes

# 4) iOS plist (flutterfire bazen atlar)
npx -y firebase-tools@latest apps:sdkconfig IOS 1:512275443807:ios:2f91baf3ec6c1dbcf8abea --project tostusahane-e4e71 -o ios/Runner/GoogleService-Info.plist

# 5) Auth email/password provider deploy
npx -y firebase-tools@latest deploy --only auth --project tostusahane-e4e71

# 6) Cloud Functions bağımlılıkları
Push-Location functions
npm install
Pop-Location

# 7) Firestore kuralları, indeksler ve FCM Cloud Function deploy
npx -y firebase-tools@latest deploy --only firestore,functions --project tostusahane-e4e71

Write-Host ""
Write-Host "Firebase baglandi. Uygulamayi calistirmak icin:"
Write-Host "  flutter run -d chrome"
Write-Host ""
Write-Host "Mock API (gelistirme, varsayilan):"
Write-Host "  flutter run"
Write-Host ""
Write-Host "Firestore backend (production):"
Write-Host '  flutter run --dart-define=USE_MOCK_API=false'
Write-Host ""
Write-Host "REST API ile (alternatif):"
Write-Host '  flutter run --dart-define=USE_MOCK_API=false --dart-define=API_BASE_URL=https://api.tostusahane.com/v1'
Write-Host ""
Write-Host "Demo kuponlar: SAHANE10, TOS20 | Demo OTP: 123456"
