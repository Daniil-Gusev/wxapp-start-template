#pragma once
#include <wx/event.h>
#include <wx/frame.h>
#include <wx/menu.h>
#include <wx/string.h>
#include <wx/utils.h>
#include <wx/windowid.h>

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
  void OnAbout(wxCommandEvent& event);
  void OnCloseMenu(wxCommandEvent& event);
  void OnExit(wxCommandEvent& event);
  void OnCloseWindow(wxCloseEvent& event);
#ifndef __WXMAC__
  void OnToggleFullScreen(wxCommandEvent& event);
#endif

  inline static wxWindowID ID_TOGGLE_FULLSCREEN = wxNewId();
};
