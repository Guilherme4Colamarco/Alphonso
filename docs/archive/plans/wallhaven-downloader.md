# Implementation Plan: Wallhaven Wallpaper Search & Downloader

**Project:** Kamalen Shell  
**Feature:** Dynamic Wallhaven Downloader  
**Goal:** Implement the backend helper and frontend UI components to search and download wallpapers in Kamalen Shell.

---

## Task Breakdown & Order of Execution

### Phase 1: Backend Helper Implementation
- [ ] **Task 1.1**: Create the `.config/quickshell/wallhaven/` directory.
- [ ] **Task 1.2**: Implement `wallhaven.py` inside `.config/quickshell/wallhaven/` using pure Python `urllib` and `PIL`.
- [ ] **Task 1.3**: Validate the CLI commands locally in the terminal:
  - Search: `python3 wallhaven.py search --query "cyberpunk"` (should output a JSON array of search results).
  - Download: `python3 wallhaven.py download --url "..." --id "test" --ext ".jpg" --out-dir "~/wallpapers"` (should stream progress and output success path + generate thumbnail in `~/.cache/wallpaper-thumbs/`).

### Phase 2: Configuration & State Updates
- [ ] **Task 2.1**: Update `UIState.qml` to register persistent config states:
  - `property string wallhavenApiKey: ""`
  - `property string wallhavenSorting: "relevance"` (allow sorting by relevance, hot, toplist, views, random, etc.)
  - `property string wallhavenCategories: "111"` (General/Anime/People)

### Phase 3: Frontend Tab Navigation & State
- [ ] **Task 3.1**: Modify `Wallpaper.qml` header to introduce Tab Buttons:
  - Tab 1: **Local** (displays the existing 3D carousel).
  - Tab 2: **Wallhaven** (displays the new online search grid).
- [ ] **Task 3.2**: Bind keyboard shortcuts (`Tab` key or arrow keys) to swap between the tabs.
- [ ] **Task 3.3**: Ensure the search input behaves contextually:
  - In "Local" tab, typing filters the local model.
  - In "Wallhaven" tab, typing and pressing `Enter` spawns the search helper process.

### Phase 4: API Process & Model Binding
- [ ] **Task 4.1**: Declare the `searchProc` `Process` block in `Wallpaper.qml` with `SplitParser`.
- [ ] **Task 4.2**: Bind search results to an `onlineModel` `ListModel`.
- [ ] **Task 4.3**: Declare the `downloadProc` `Process` block. Bind stdout logs to update loading states and progress percentages in real time.

### Phase 5: Grid Interface & Download Indicators
- [ ] **Task 5.1**: Implement a custom, high-fidelity `GridView` in `Wallpaper.qml` that displays results.
- [ ] **Task 5.2**: Style result items:
  - Display CDN thumbnail.
  - Hover states showing details (resolution, size) using a sleek micro-animation.
  - Clear visual cues when selected or active.
- [ ] **Task 5.3**: Add a circular progress spinner overlay showing download percentages (`PROGRESS:XX%`).

### Phase 6: Post-Download Execution & Color Extraction
- [ ] **Task 6.1**: In the download success callback, reload the local wallpaper list and symlink the new file to `~/wallpapers/current`.
- [ ] **Task 6.2**: Trigger `applyWallpaper()` so the transition runs automatically.
- [ ] **Task 6.3**: Verify that the color extraction pipeline (`iris.py`) is triggered automatically by the `inotifywait` file watcher when the link is updated.

---

## Dependencies
- **Task 1.3** is a blocker for all frontend integration. The Python script must be completely stable and correct first.
- **Phase 3** must be completed before layout grid design in **Phase 5** because we need the tab structure to host the new grid container.
