# Changelog

## 1.0.4 — 2026-10-18

- ⇧ opens the ring instantly: Kumquat now watches the drag from the moment you press, instead of waiting for drag events macOS stops sending
- The ring is truly round: the frosted glass is clipped to a circle and the shadow no longer gets cut into a square
- Faster, snappier ring animation; the ring is prepared at launch

## 1.0.3 — 2026-10-18

- "Update Now" button right in the update notification, and in Settings → About
- Updating from the app is more reliable: Kumquat quits, gets replaced and reopens by itself

## 1.0.2 — 2026-10-18

- The ring is a perfect circle: no more faint square or line around it
- Formats & Tools shows one kind of file at a time, so Settings scroll smoothly

## 1.0.1 — 2026-10-18

- Settings scroll smoothly: Formats & Tools no longer lags

## 1.0.0 — 2026-10-18

First release.

**The gesture**
- Grab any file, move it a little, tap ⇧ and drop it on a glass ring that opens under the cursor
- Tap ⇧ again to switch between Convert and Tools; progress and a ✓ show inside the ring
- Also from ⌃⌥K (Finder selection), the menu bar icon (drop files on it), Services, Open With

**Formats** (60+ without extra software)
- Images: JPG, PNG, HEIC, AVIF, TIFF, GIF, BMP, ICO, ICNS, PSD, PDF; reads SVG, RAW, WebP, JPEG XL
- PDF → images, one long image, TXT, Word, EPUB, RTF, HTML
- Documents (TXT, Markdown, RTF, Word, HTML, ODT) ↔ PDF, DOCX, EPUB, TXT, RTF, HTML, ODT
- E-books: EPUB → PDF, DOCX, TXT, HTML, RTF
- Spreadsheets & data: CSV, TSV, XLSX, JSON, PLIST, HTML and PDF tables
- Subtitles: SRT ↔ VTT, transcripts
- Video → MP4, MOV, M4V, GIF, M4A; audio → M4A, WAV, AIFF, FLAC, CAF
- Archives: ZIP anything (files and folders); extract ZIP, RAR, 7Z, TAR, GZ…; repack as ZIP or TAR.GZ
- Optional engines, used only if installed: FFmpeg (WebM, MKV, AVI, MP3, OGG, OPUS…), WebP, Ghostscript, LibreOffice (Office files)

**Tools**
- Compress, Resize, Crop, Add Background, Remove Background (photos and plain backdrops like signatures), Get Text (OCR → clipboard), strip metadata, Rotate, Flip, B&W
- PDF Compress (balanced / strongest), Merge, Split, Rotate, Protect, One Image
- Video Compress, Mute, Frames

**Everything else**
- Watch folders, the `kumquat` command, recent conversions, update notifications
- Notifications with size change, Show in Finder, Open and Undo; nothing is saved when compressing can't help
- Settings: themes and custom colors, glass material, size, opacity, labels, trigger key, which slices appear and their order, where to save, quality
- 9 languages: English, Español, Português, Français, Deutsch, Italiano, 日本語, 한국어, 简体中文
- Opens at login by default
