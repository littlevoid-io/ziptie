export interface LockdownTaskSpec {
  title: string;
  file: string;
  action?: string;
  undoAction?: string;
  configKey: string;
}

export const OS_LOCKDOWN_TASKS: LockdownTaskSpec[] = [
  { title: 'Windows Widgets', file: 'disable-windows-widgets.ps1', configKey: 'disableWindowsWidgets' },
  { title: 'Copilot & Recall AI', file: 'disable-copilot-recall.ps1', configKey: 'disableCopilotRecall' },
  { title: 'Windows Update Policies', file: 'disable-update-service.ps1', action: 'Configuring', undoAction: 'Restoring', configKey: 'disableWindowsUpdate' },
  { title: 'Screensaver & Standby', file: 'disable-screensaver.ps1', configKey: 'disableScreensaver' },
  { title: 'Accessibility Shortcuts', file: 'disable-accessibility.ps1', configKey: 'disableAccessibilityShortcuts' },
  { title: 'Screen Edge Swipes', file: 'disable-edge-swipes.ps1', configKey: 'disableEdgeSwipes' },
  { title: 'Visual Touch Feedback', file: 'disable-touch-feedback.ps1', configKey: 'disableTouchFeedback' },
  { title: 'Windows System Sounds', file: 'disable-system-sounds.ps1', configKey: 'disableSystemSounds' },
  { title: 'Setup Prompts & OOBE', file: 'disable-win-setup-prompts.ps1', configKey: 'disableOOBEPrompts' },
  { title: 'Default Desktop Icons', file: 'clear-desktop-shortcuts.ps1', action: 'Clearing', undoAction: 'Restoring', configKey: 'clearDesktopIcons' },
  { title: 'Solid Color Background', file: 'set-desktop-background.ps1', action: 'Applying', undoAction: 'Restoring', configKey: 'solidColorBackground' },
  { title: 'Windows Dark Mode', file: 'enable-dark-mode.ps1', action: 'Configuring', undoAction: 'Restoring', configKey: 'enableDarkMode' },
  { title: 'File Explorer Defaults', file: 'config-explorer.ps1', action: 'Configuring', undoAction: 'Restoring', configKey: 'configureExplorer' },
  { title: 'Automatic App Installs', file: 'disable-app-installs.ps1', configKey: 'disableAppInstalls' },
  { title: 'App Restore Features', file: 'disable-app-restore.ps1', configKey: 'disableAppRestore' },
  { title: 'Windows Error Reporting', file: 'disable-error-reporting.ps1', configKey: 'disableErrorReporting' },
  { title: 'Network Firewalls', file: 'disable-firewall.ps1', action: 'Disabling', undoAction: 'Enabling', configKey: 'disableFirewall' },
  { title: 'Win32 Long Paths Support', file: 'disable-max-path-length.ps1', action: 'Enabling', undoAction: 'Disabling', configKey: 'disableMaxPathLength' },
  { title: 'New Network Dialog Popups', file: 'disable-new-network-window.ps1', configKey: 'disableNewNetworkWindow' },
  { title: 'Toast Notifications', file: 'disable-notifications.ps1', configKey: 'disableNotifications' },
  { title: 'Touchpad Edge Gestures', file: 'disable-touch-gestures.ps1', configKey: 'disableTouchGestures' },
  { title: 'PowerShell Script Execution', file: 'enable-script-execution.ps1', action: 'Enabling', undoAction: 'Restoring', configKey: 'enableScriptExecution' },
  { title: 'Desktop Text Scale Factor', file: 'reset-text-scale.ps1', action: 'Resetting', undoAction: 'Restoring', configKey: 'resetTextScale' },
  { title: 'Windows Bloatware', file: 'uninstall-bloatware.ps1', action: 'Uninstalling', undoAction: 'Restoring', configKey: 'uninstallBloatware' },
  { title: 'Microsoft OneDrive', file: 'uninstall-one-drive.ps1', action: 'Uninstalling', undoAction: 'Restoring', configKey: 'uninstallOneDrive' },
  { title: 'Default Start Menu Apps', file: 'unpin-start-menu-apps.ps1', action: 'Unpinning', undoAction: 'Restoring', configKey: 'unpinStartMenuApps' },
  { title: 'Active Power Scheme', file: 'set-power-settings.ps1', action: 'Configuring', undoAction: 'Restoring', configKey: 'setPowerSettings' }
];
