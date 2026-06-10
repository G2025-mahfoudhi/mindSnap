module SettingsHelper
  def settings_tab(tab, label, active_tab)
    is_active = tab == active_tab
    link_to label,
            settings_path(tab: tab),
            class: "nav-link #{'active' if is_active}",
            role: "tab"
  end
end
