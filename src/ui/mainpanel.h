#pragma once
#include <wx/panel.h>

class MainPanel : public wxPanel {
 public:
  MainPanel(wxWindow* parent);

 private:
  void SetupUI();
};
