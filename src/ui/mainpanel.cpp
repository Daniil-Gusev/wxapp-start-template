#include "mainpanel.h"

#include <wx/sizer.h>
#include <wx/stattext.h>

MainPanel::MainPanel(wxWindow* parent) : wxPanel(parent, wxID_ANY) {
  SetupUI();
}

void MainPanel::SetupUI() {
  auto* mainSizer = new wxBoxSizer(wxVERTICAL);
  auto* welcomeText =
      new wxStaticText(this, wxID_ANY, _("Your interface will be here."));
  mainSizer->Add(welcomeText, 0, wxALIGN_CENTER | wxALL, 20);
  SetSizer(mainSizer);
}
