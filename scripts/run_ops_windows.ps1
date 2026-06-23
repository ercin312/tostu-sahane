# Windows şube / yönetici masaüstü sürümünü geliştirme modunda çalıştırır.
Set-Location $PSScriptRoot\..
flutter run -d windows --dart-define=OPS_DESKTOP=true --dart-define=USE_MOCK_API=false
