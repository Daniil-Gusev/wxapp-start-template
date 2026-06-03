#include "app.h"

#include <wx/app.h>
#include <wx/config.h>
#include <wx/filename.h>
#include <wx/log.h>
#include <wx/msgdlg.h>
#include <wx/string.h>
#include <wx/translation.h>
#include <wx/uilocale.h>

#include <memory>

#include "mainframe.h"
#include "version.h"

wxIMPLEMENT_APP(App);

bool App::OnInit() {
  if (!wxApp::OnInit()) return false;
  SetAppName(APP_NAME);
  SetVendorName(APP_VENDOR);
  m_instanceChecker = std::make_unique<wxSingleInstanceChecker>();
  if (m_instanceChecker->IsAnotherRunning()) {
    wxMessageBox(wxString::Format("%s уже запущен.", APP_NAME), APP_NAME,
                 wxOK | wxICON_WARNING);
    return false;
  }
  wxConfigBase::Set(new wxFileConfig());
  wxUILocale::UseDefault();
  auto* tr = new wxTranslations();
  wxTranslations::Set(tr);
  tr->AddCatalog(APP_NAME);
  tr->AddCatalog("wxstd");
#ifdef __WXMAC__
  this->SetExitOnFrameDelete(false);
  Bind(wxEVT_ACTIVATE_APP, &App::OnActivate, this);
#endif
  CreateMainWindow();
  return true;
}

void App::CreateMainWindow() {
  MainFrame* frame = new MainFrame("example");
  SetTopWindow(frame);
  frame->Fit();
  frame->Show(true);
  frame->Raise();
  frame->SetFocus();
}

bool App::OnExceptionInMainLoop() {
  try {
    throw;
  } catch (const std::exception& e) {
    wxLogError("Unhandled exception: %s", e.what());
    wxMessageBox(wxString::Format("Произошла ошибка: %s", e.what()), "Ошибка",
                 wxOK | wxICON_ERROR);
  } catch (...) {
    wxLogError("Unknown unhandled exception");
  }
  return false;
}

void App::OnUnhandledException() { OnExceptionInMainLoop(); }

#ifdef __WXMAC__
void App::OnActivate(wxActivateEvent& event) {
  if (event.GetActive() && !GetTopWindow()) CreateMainWindow();
  event.Skip();
}
#endif
