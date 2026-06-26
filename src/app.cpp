#include "app.h"

#include <wx/app.h>
#include <wx/config.h>
#include <wx/ffile.h>
#include <wx/filename.h>
#include <wx/log.h>
#include <wx/msgdlg.h>
#include <wx/stdpaths.h>
#include <wx/string.h>
#include <wx/translation.h>
#include <wx/uilocale.h>

#include <exception>
#include <memory>

#include "mainframe.h"
#include "version.h"

wxIMPLEMENT_APP(App);

bool App::OnInit() {
  if (!wxApp::OnInit()) return false;
  SetAppName(APP_NAME);
  SetVendorName(APP_VENDOR);
  m_instanceChecker = std::make_unique<wxSingleInstanceChecker>();
  if (m_instanceChecker->IsAnotherRunning())
    wxLogFatalError(_("Application '%s' is already running."), GetAppName());
  SetupLocalization();
  if (!SetupLogging()) return false;
#ifdef __WXMAC__
  this->SetExitOnFrameDelete(false);
  Bind(wxEVT_ACTIVATE_APP, &App::OnActivate, this);
#endif
  wxLogVerbose("%s %s (%s) started.", APP_NAME, APP_VERSION, APP_REVISION);
  CreateMainWindow();
  return true;
}

void App::SetupLocalization() {
  wxUILocale::UseDefault();
  auto* tr = new wxTranslations();
  wxTranslations::Set(tr);
  wxFileName exePath(wxStandardPaths::Get().GetExecutablePath());
  wxString baseDir = exePath.GetPath();
#ifdef __WXMSW__
  wxString localeDir = baseDir + wxFILE_SEP_PATH + "locale";
  wxFileTranslationsLoader::AddCatalogLookupPathPrefix(localeDir);
#elif defined(__linux__)
  wxString localeDir = baseDir + wxFILE_SEP_PATH + ".." + wxFILE_SEP_PATH +
                       "share" + wxFILE_SEP_PATH + "locale";
  wxFileTranslationsLoader::AddCatalogLookupPathPrefix(localeDir);
#endif

  tr->AddCatalog(APP_NAME);
  tr->AddCatalog("wxstd");
}

bool App::SetupLogging() {
  delete wxLog::SetActiveTarget(new wxLogStderr());
  wxLog::SetVerbose(true);
  wxString dataDir = wxStandardPaths::Get().GetUserDataDir();
  if (!wxFileName::Mkdir(dataDir, wxS_DIR_DEFAULT, wxPATH_MKDIR_FULL)) {
    wxLogError("Directory '%s' couldn't be created", dataDir);
    wxMessageBox(
        wxString::Format(_("Directory '%s' couldn't be created"), dataDir),
        _("Error"), wxICON_ERROR);
    return false;
  }
  wxString logPath = dataDir + wxFILE_SEP_PATH + GetAppName() + ".log";
  if (!m_logFile.Open(logPath, "a")) {
    wxLogError("Failed to open '%s' for writing", logPath);
    wxMessageBox(
        wxString::Format(_("Failed to open '%s' for writing"), logPath),
        _("Warning"), wxICON_WARNING);
    return true;
  }
  delete wxLog::SetActiveTarget(new wxLogStderr(m_logFile.fp()));
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
    wxString msg = e.what();
    wxLogError("Unhandled exception: %s", msg);
    wxMessageBox(wxString::Format(_("Unhandled exception: %s"), msg),
                 _("Error"), wxICON_ERROR);
  } catch (...) {
    wxLogError("Unknown unhandled exception");
    wxMessageBox(_("Unknown unhandled exception"), _("Error"), wxICON_ERROR);
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
