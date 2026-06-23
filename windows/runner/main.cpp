#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>

#include "flutter_window.h"
#include "utils.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to parent console (batch) or create one for boot_log diagnosis.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS)) {
    wchar_t exe_path[MAX_PATH];
    if (::GetModuleFileNameW(nullptr, exe_path, MAX_PATH) != 0) {
      std::wstring exe_dir(exe_path);
      const auto slash = exe_dir.find_last_of(L"\\/");
      if (slash != std::wstring::npos) {
        exe_dir.resize(slash);
      }
      const std::wstring verbose_flag = exe_dir + L"\\verbose.txt";
      if (::GetFileAttributesW(verbose_flag.c_str()) != INVALID_FILE_ATTRIBUTES) {
        CreateAndAttachConsole();
      }
    }
  } else if (::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  // Entegre GPU / WARP yolu; eski ekran kartlarinda cokme riskini azaltir.
  project.set_gpu_preference(flutter::GpuPreference::LowPowerPreference);

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1400, 900);
  if (!window.Create(L"Tostu Sahane - Operasyon", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(true);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
