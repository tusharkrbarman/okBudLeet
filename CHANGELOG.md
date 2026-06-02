# Changelog

All notable changes to BuddyCode are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] — Initial Release

### Added
- Company tags sourced from `snehasishroy/leetcode-companywise-interview-questions`, including a "recent 6 months" view.
- Interview frequency pill (%) injected next to the difficulty tag.
- ELO rating from `zerotrac/leetcode_problem_rating` with Grandmaster / Master / Expert / Hard / Medium / Easy label.
- Time & space complexity badges for 1,000+ problems.
- Post-submission diagnostics panel (Approach / Efficiency / Code Style tabs) on the submission page.
- Light and dark mode.
- SPA navigation observer so widgets re-inject on LeetCode route changes.
- 7-day cache for company tags, frequencies, and ELO ratings.
- Settings popup with per-feature toggles.

### Security
- HTML-escaped all interpolations in the submission panel's `innerHTML` template to prevent injection from URL slugs.
- Silenced console warnings so the extension is not fingerprintable in DevTools.
- Removed dead CSS from the popup after feature cleanup.
