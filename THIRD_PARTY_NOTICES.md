# Source and third-party notices

MacSizeExplorer is an independent disk usage visualization app for macOS. Its source was developed for this project with AI assistance. It is not a port of WinDirStat and does not include WinDirStat source, binaries, artwork, or logos. References to WinDirStat describe the category of application; no affiliation or endorsement is claimed.

## Project license

The project source and original assets are distributed under the MIT License in `LICENSE`. The same license is included in the application bundle and downloadable archive. This license does not relicense Apple software, system fonts, or system-provided symbols.

## System frameworks and symbols

The app links to macOS-provided Cocoa/AppKit, Foundation, UniformTypeIdentifiers, and Darwin APIs. Apple's system frameworks, SDK files, and font files are not copied into this repository or application bundle. System symbols are requested by name using `NSImage(systemSymbolName:accessibilityDescription:)` and appear only as controls inside the macOS user interface. No exported SF Symbols artwork is included in the repository or used as the application icon or product logo.

Apple's [SF Symbols guidance](https://developer.apple.com/design/human-interface-guidelines/sf-symbols) describes interface use and restrictions on symbols in application icons, logos, and trademark uses. These system resources remain subject to Apple's applicable terms.

## Distribution review — 2026-10-26

- Reviewed the files selected for publication, build script, and archive contents.
- No copied third-party code, package dependencies, bundled SDKs, fonts, or external artwork were identified in the reviewed source and deliverables.
- Preview images use synthetic `/Demo/` data, not a scan of a user's files.
- No credentials, private scan exports, or user file listings are intended for publication.
- The application makes no network requests and does not delete files. CSV export occurs only at a location chosen by the user.
- The application is ad hoc signed, not Developer ID signed or notarized by Apple. macOS may require the user to approve opening it.
- No trademark registration search or patent clearance was performed for the product name. This review is limited to the supplied project contents and is not legal advice or a guarantee against third-party claims.
