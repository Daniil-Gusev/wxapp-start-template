#include "mainframe.h"

#include <wx/aboutdlg.h>
#include <wx/app.h>
#include <wx/config.h>
#include <wx/msgdlg.h>
#include <wx/persist.h>
#include <wx/persist/toplevel.h>
#include <wx/sizer.h>
#include <wx/translation.h>

#include "mainpanel.h"
#include "version.h"

MainFrame::MainFrame(const wxString& title)
    : wxFrame(nullptr, wxID_ANY, title, wxDefaultPosition, wxDefaultSize) {
  CreateMenu();
  CreateMainPanel();
  BindEvents();
  if (!wxPersistenceManager::Get().RegisterAndRestore(this)) Fit();
}

void MainFrame::CreateMenu() {
  auto* menuBar = new wxMenuBar();
  menuBar->Append(CreateFileMenu(), _("&File"));
  menuBar->Append(CreateViewMenu(), _("&View"));
#ifdef __WXMAC__
  menuBar->Append(new wxMenu(), _("&Window"));
#endif
  menuBar->Append(CreateHelpMenu(), _("&Help"));
  SetMenuBar(menuBar);
}

wxMenu* MainFrame::CreateFileMenu() {
  auto* fileMenu = new wxMenu();
  fileMenu->Append(wxID_CLOSE, "");
  Bind(wxEVT_MENU, &MainFrame::OnCloseMenu, this, wxID_CLOSE);
  fileMenu->Append(wxID_EXIT, "");
  Bind(wxEVT_MENU, &MainFrame::OnExit, this, wxID_EXIT);
  return fileMenu;
}

wxMenu* MainFrame::CreateViewMenu() {
  auto* viewMenu = new wxMenu();
#ifndef __WXMAC__
  viewMenu->AppendCheckItem(ID_TOGGLE_FULLSCREEN, _("Full Screen\tF11"));
  Bind(wxEVT_MENU, &MainFrame::OnToggleFullScreen, this, ID_TOGGLE_FULLSCREEN);
#endif
  return viewMenu;
}

wxMenu* MainFrame::CreateHelpMenu() {
  auto* helpMenu = new wxMenu();
  helpMenu->Append(wxID_ABOUT, "");
  Bind(wxEVT_MENU, &MainFrame::OnAbout, this, wxID_ABOUT);
  return helpMenu;
}

void MainFrame::CreateMainPanel() {
  auto* frameSizer = new wxBoxSizer(wxVERTICAL);
  auto* mainContent = new MainPanel(this);
  frameSizer->Add(mainContent, 1, wxEXPAND);
  SetSizer(frameSizer);
}

void MainFrame::BindEvents() {
  Bind(wxEVT_CLOSE_WINDOW, &MainFrame::OnCloseWindow, this);
}

bool MainFrame::CanCloseApp() { return true; }

void MainFrame::OnCloseMenu(wxCommandEvent&) { Close(false); }

void MainFrame::OnCloseWindow(wxCloseEvent& event) {
  if (!CanCloseApp() && event.CanVeto()) {
    int answer = wxMessageBox(
        _("You have unsaved data! Are you sure you want to exit?"),
        _("Exit request"), wxYES_NO | wxNO_DEFAULT | wxICON_WARNING, this);
    if (answer == wxNO) {
      event.Veto();
      return;
    }
  }
  wxPersistenceManager::Get().SaveAndUnregister(this);
  event.Skip();
}

void MainFrame::OnExit(wxCommandEvent&) {
  if (Close(false)) wxExit();
}

void MainFrame::OnAbout(wxCommandEvent&) {
  wxAboutDialogInfo info;
  info.SetName(wxGetTranslation(APP_NAME));
  info.SetVersion(APP_REVISION, APP_VERSION);
  info.SetDescription(wxGetTranslation(APP_DESCRIPTION));
  info.SetCopyright(wxGetTranslation(APP_COPYRIGHT));
  wxAboutBox(info, this);
}

#ifndef __WXMAC__
void MainFrame::OnToggleFullScreen(wxCommandEvent&) {
  ShowFullScreen(!IsFullScreen());
  auto* menuBar = GetMenuBar();
  if (menuBar) menuBar->Check(ID_TOGGLE_FULLSCREEN, IsFullScreen());
}
#endif
