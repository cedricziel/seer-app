## ADDED Requirements

### Requirement: Predictable app settings
Every primary tab SHALL expose a labeled Settings action. Settings SHALL group server management, download preferences, privacy and diagnostics, and feedback. Quick server switching SHALL remain separate. Privacy and feedback SHALL no longer be nested under Manage Servers.

#### Scenario: Settings from every tab
- **WHEN** a user on iPhone compact width, iPad regular width, or tvOS opens Settings from any primary tab
- **THEN** Servers, Downloads, Privacy & Diagnostics, and Send Feedback are available

#### Scenario: Existing preferences remain available
- **WHEN** a user on iPad regular width opens Downloads from Settings
- **THEN** existing download preferences and auto-download rules are available with a return path to Settings
