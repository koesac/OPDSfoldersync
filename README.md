# OPDSfoldersync - Koreader OPDS Plugin with Per-Catalog Sync

This project provides an enhanced OPDS (Open Publication Distribution System) plugin for Koreader, enabling users to browse, download, and synchronize content from OPDS catalogs. A key feature of this plugin is the ability to configure *per-catalog synchronization folders*, allowing for more organized management of downloaded books and documents.

## Features

*   **OPDS Catalog Browsing:** Seamlessly browse and discover content from various OPDS feeds.
*   **Per-Catalog Sync Folders:** Assign a dedicated synchronization directory for each OPDS catalog, preventing clutter and improving organization of your downloaded files.
*   **Global Sync Directory:** Fallback to a global synchronization directory if a per-catalog folder is not specified.
*   **Configurable Download Behavior:** Options for using server filenames and enabling/disabling sync per catalog.

## Installation

To install the OPDSfoldersync plugin, follow these steps:

1.  **Locate your Koreader installation directory.** This is typically where your `koreader.app` or `koreader.sh` executable resides.
2.  **Navigate to the `plugins` directory** within your Koreader installation (e.g., `/koreader/plugins/`).
3.  **Copy the `opds.koplugin` folder** from this repository directly into Koreader's `plugins` directory.
    *   Make sure you copy the entire `opds.koplugin` directory, not just its contents.

Your directory structure should look something like this:

```
/koreader/
├── plugins/
│   ├── opds.koplugin/
│   │   ├── _meta.lua
│   │   ├── main.lua
│   │   ├── opdsbrowser.lua
│   │   ├── opdsparser.lua
│   │   └── opdspse.lua
│   └── (other plugins...)
├── (other Koreader files...)
```

4.  **Restart Koreader** to load the new plugin.

## Usage

### Adding/Editing an OPDS Catalog

1.  From the Koreader file browser, access the **"Network"** menu (usually a Wi-Fi or globe icon).
2.  Select **"OPDS"**.
3.  Choose **"Add new catalog"** or select an existing catalog and choose **"Edit catalog"**.
4.  Fill in the catalog details (Name, URL, Username, Password).
5.  **Sync Catalog:** Check this option if you want Koreader to automatically synchronize content from this catalog.
6.  **Set Sync Folder:** A new button labeled "Set sync folder" (or "Sync folder: [path]" if already set) will allow you to choose a specific directory on your device where books from *this catalog* will be downloaded. If left unset, the global sync folder or default download directory will be used.
7.  Tap **"Save"**.

### Synchronization

*   When "Sync Catalog" is enabled for a catalog, Koreader will attempt to download new items from that catalog into its designated sync folder.
*   The plugin prioritizes the per-catalog sync folder. If not set, it falls back to the global `sync_dir` setting (if configured in Koreader settings), and finally to Koreader's default download directory.

## Configuration

Global OPDS settings, such as a default synchronization directory for all catalogs, can typically be found within Koreader's general settings under "Network" or "OPDS". However, the per-catalog setting introduced by this plugin will override the global setting for specific catalogs.

---
**Note:** This plugin assumes a Koreader environment capable of running Lua plugins and accessing the file system.
