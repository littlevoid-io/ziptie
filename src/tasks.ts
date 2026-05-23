export interface LockdownTaskSpec {
  title: string;
  file: string;
  action?: string;
  undoAction?: string;
}

export const OS_LOCKDOWN_TASKS: LockdownTaskSpec[] = [
  { title: 'Windows Widgets', file: 'disable-windows-widgets.ps1' },
  { title: 'Copilot & Recall AI', file: 'disable-copilot-recall.ps1' },
  { title: 'Windows Update Policies', file: 'disable-update-service.ps1', action: 'Configuring', undoAction: 'Restoring' },
  { title: 'Screensaver & Standby', file: 'disable-screensaver.ps1' },
  { title: 'Accessibility Shortcuts', file: 'disable-accessibility.ps1' },
  { title: 'Screen Edge Swipes', file: 'disable-edge-swipes.ps1' },
  { title: 'Visual Touch Feedback', file: 'disable-touch-feedback.ps1' },
  { title: 'Windows System Sounds', file: 'disable-system-sounds.ps1' },
  { title: 'Setup Prompts & OOBE', file: 'disable-win-setup-prompts.ps1' },
  { title: 'Default Desktop Icons', file: 'clear-desktop-shortcuts.ps1', action: 'Clearing', undoAction: 'Restoring' },
  { title: 'Solid Color Background', file: 'set-desktop-background.ps1', action: 'Applying', undoAction: 'Restoring' },
  { title: 'Windows Dark Mode', file: 'enable-dark-mode.ps1', action: 'Configuring', undoAction: 'Restoring' },
  { title: 'File Explorer Defaults', file: 'config-explorer.ps1', action: 'Configuring', undoAction: 'Restoring' },
  { title: 'Automatic App Installs', file: 'disable-app-installs.ps1' },
  { title: 'App Restore Features', file: 'disable-app-restore.ps1' },
  { title: 'Windows Error Reporting', file: 'disable-error-reporting.ps1' },
  { title: 'Network Firewalls', file: 'disable-firewall.ps1', action: 'Disabling', undoAction: 'Enabling' },
  { title: 'Win32 Long Paths Support', file: 'disable-max-path-length.ps1', action: 'Enabling', undoAction: 'Disabling' },
  { title: 'New Network Dialog Popups', file: 'disable-new-network-window.ps1' },
  { title: 'Toast Notifications', file: 'disable-notifications.ps1' },
  { title: 'Touchpad Edge Gestures', file: 'disable-touch-gestures.ps1' },
  { title: 'PowerShell Script Execution', file: 'enable-script-execution.ps1', action: 'Enabling', undoAction: 'Restoring' },
  { title: 'Desktop Text Scale Factor', file: 'reset-text-scale.ps1', action: 'Resetting', undoAction: 'Restoring' },
  { title: 'Windows Bloatware', file: 'uninstall-bloatware.ps1', action: 'Uninstalling', undoAction: 'Restoring' },
  { title: 'Microsoft OneDrive', file: 'uninstall-one-drive.ps1', action: 'Uninstalling', undoAction: 'Restoring' },
  { title: 'Default Start Menu Apps', file: 'unpin-start-menu-apps.ps1', action: 'Unpinning', undoAction: 'Restoring' },
  { title: 'Active Power Scheme', file: 'set-power-settings.ps1', action: 'Configuring', undoAction: 'Restoring' }
];
