#pragma once
#include <wx/app.h>
#include <wx/config.h>
#include <wx/snglinst.h>

#include <memory>

class App : public wxApp {
 public:
  bool OnInit();
  void CreateMainWindow();
  wxConfigBase& GetConfig() { return *wxConfigBase::Get(); }
  bool OnExceptionInMainLoop();
  void OnUnhandledException();

 private:
  std::unique_ptr<wxSingleInstanceChecker> m_instanceChecker;

#ifdef __WXMAC__
  void OnActivate(wxActivateEvent& event);
#endif
};

wxDECLARE_APP(App);
