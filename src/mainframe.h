#pragma once
#include <wx/event.h>
#include <wx/frame.h>
#include <wx/menu.h>
#include <wx/string.h>

class MainFrame : public wxFrame {
 public:
  MainFrame(const wxString& title);

 protected:
  virtual bool CanCloseApp();

 private:
  void CreateMenu();
  wxMenu* CreateFileMenu();
  wxMenu* CreateViewMenu();
  wxMenu* CreateHelpMenu();
  void CreateMainPanel();
  void BindEvents();
  void SaveGeometry();
  bool RestoreGeometry();
  void OnAbout(wxCommandEvent& event);
  void OnCloseMenu(wxCommandEvent& event);
  void OnExit(wxCommandEvent& event);
  void OnCloseWindow(wxCloseEvent& event);
  void OnToggleFullScreen(wxCommandEvent& event);

  enum { ID_TOGGLE_FULLSCREEN = wxID_HIGHEST + 1 };
};
