## Context

Five tabs remain. Existing Search is a Jellyseerr request journey. Server management contains unrelated app preferences.

## Goals / Non-Goals

Deliver active-server library search and a predictable Settings entry. Collection navigation, unified title details, and a sidebar redesign remain separate work.

## Decisions

- Use a Library/Catalog picker in Search, defaulting to Library. This preserves catalog behavior while making the search boundary explicit.
- Use JellyfinClient.getItems with SearchTerm and pagination. A small injectable search model owns debounce, replacement, retry, and pagination state; existing MediaDetailView owns detail/playback behavior.
- Reset the Search subtree on active-server changes to prevent stale results and detail credentials.
- Add a Settings toolbar button on each tab. Use a Settings navigation stack with links to Privacy and Feedback and sheets for the existing self-contained server/download editors. Avoid a sixth tab and nested navigation stacks.
- Dependency direction remains features → clients → SeerCore. No new module dependencies.

## HIG & Layout

### iPhone (compact width)

Use native searchable input and a two-option scope picker above results. Use a vertical results list with wrapping text in portrait and landscape. Settings uses native grouped list rows and labeled toolbar actions.

### iPad (regular width)

Retain the existing tab shell. Results and Settings use flexible lists and system sheet sizing in full width, split-view 1/3, 1/2, 2/3, Slide Over, and Stage Manager. Native controls provide pointer targets.

### tvOS

Use native search, picker, list, and buttons for focus traversal. The remote can reach Settings, scopes, results, retry, and Load More. Verify focus on a dedicated simulator when available.

### Aspect ratios

Lists reflow with the available width; no fixed screen height or letterboxing.

### Accessibility

Use semantic labels for Settings and scope selection, scalable text, wrapping result names, native navigation, and no custom motion. Verify VoiceOver order, Dynamic Type AX5, Reduce Motion, Reduce Transparency, Increase Contrast, and Smart Invert on isolated devices.

### HIG references

- [Searching](https://developer.apple.com/design/human-interface-guidelines/searching)
- [Settings](https://developer.apple.com/design/human-interface-guidelines/settings)
- [Toolbars](https://developer.apple.com/design/human-interface-guidelines/toolbars)

## Risks / Trade-offs

- Live search requires the server: show actionable error and retry; offline cache search is outside this slice.
- Superseded requests can finish: guard every result mutation with generation and cancellation checks.
- Existing formatting failures: report baseline failures separately and format only changed files.

## Migration Plan

No stored state changes. Existing preferences and credentials remain in their existing stores.
