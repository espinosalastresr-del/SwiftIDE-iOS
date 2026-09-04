# SwiftIDE for iPhone

**Native offline-first Swift IDE for iPhone**

Phase 1 focuses on a professional, stable and fluid code editor with full project management capabilities.

## Goals of Phase 1

- Create / open / manage projects
- Full file browser (create, rename, move, delete files & folders)
- Multi-tab code editor based on TextKit 2 / UITextView
- Syntax highlighting for Swift
- Autocomplete (keywords, Foundation, SwiftUI, project symbols)
- Search & Replace
- Autosave + recovery after suspension/crash
- Undo / Redo
- Optimized for iPhone (especially iPhone 11+)
- Completely offline

## Architecture

```
SwiftIDE/
├── App/
├── Core/
├── Models/
├── Workspace/
├── FileSystem/
├── Editor/
├── Syntax/
├── Completion/
├── Search/
├── Persistence/
├── UI/
├── Features/
└── Resources/
```

## Requirements

- iOS 17.0+
- Xcode 16+

## Building

The project is built and packaged via GitHub Actions. Every push to `main` or tags produces an unsigned IPA artifact ready for sideloading / testing.

## Versioning

Semantic Versioning:
- `0.1.0` → Phase 1 Editor
- Subsequent patches and minor versions as features stabilize

## License

Proprietary for now (to be decided).
