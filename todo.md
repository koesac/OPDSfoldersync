I'll help you implement per-catalog sync folders for the OPDS plugin. Here's the implementation plan:

## Implementation Overview

To add per-catalog sync folders, we need to modify the catalog structure and related functions in `opdsbrowser.lua` [1](#1-0) .

## Changes Required

### 1. Update Catalog Structure

Modify `buildRootEntry()` to include the `sync_dir` field [2](#1-1) :

```lua
local function buildRootEntry(server)
    local icons = ""
    if server.username then
        icons = "\u{f2c0}"
    end
    if server.sync then
        icons = "\u{f46a} " .. icons
    end
    return {
        text       = server.title,
        mandatory  = icons,
        url        = server.url,
        username   = server.username,
        password   = server.password,
        raw_names  = server.raw_names,
        searchable = server.url and server.url:match("%%s") and true or false,
        sync       = server.sync,
        sync_dir   = server.sync_dir,  -- Add this line
    }
end
```

### 2. Modify Catalog Edit Dialog

Update `addEditCatalog()` to add a folder selection button [3](#1-2) :

```lua
function OPDSBrowser:addEditCatalog(item)
    local fields = {
        {
            hint = _("Catalog name"),
        },
        {
            hint = _("Catalog URL"),
        },
        {
            hint = _("Username (optional)"),
        },
        {
            hint = _("Password (optional)"),
            text_type = "password",
        },
    }
    local title
    if item then
        title = _("Edit OPDS catalog")
        fields[1].text = item.text
        fields[2].text = item.url
        fields[3].text = item.username
        fields[4].text = item.password
    else
        title = _("Add OPDS catalog")
    end

    local dialog, check_button_raw_names, check_button_sync_catalog, button_sync_dir
    dialog = MultiInputDialog:new{
        title = title,
        fields = fields,
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Save"),
                    callback = function()
                        local new_fields = dialog:getFields()
                        new_fields[5] = check_button_raw_names.checked or nil
                        new_fields[6] = check_button_sync_catalog.checked or nil
                        new_fields[7] = button_sync_dir.sync_dir or nil
                        self:editCatalogFromInput(new_fields, item)
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    
    -- Existing check buttons...
    check_button_raw_names = CheckButton:new{
        text = _("Use server filenames"),
        checked = item and item.raw_names,
        parent = dialog,
    }
    check_button_sync_catalog = CheckButton:new{
        text = _("Sync catalog"),
        checked = item and item.sync,
        parent = dialog,
    }
    
    -- Add sync directory button
    button_sync_dir = Button:new{
        text = item and item.sync_dir and _("Sync folder: ") .. item.sync_dir or _("Set sync folder"),
        callback = function()
            require("ui/widget/filechooser"):new{
                title = _("Choose sync folder"),
                path = item and item.sync_dir or self.settings.sync_dir or require("ffi/util").realpath("."),
                show_hidden = G_reader_settings:readSetting("show_hidden"),
                select_callback = function(path)
                    button_sync_dir.sync_dir = path
                    button_sync_dir:setText(_("Sync folder: ") .. path)
                end,
            }:show()
        end,
    }
    
    dialog:addWidget(check_button_raw_names)
    dialog:addWidget(check_button_sync_catalog)
    dialog:addWidget(button_sync_dir)
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end
```

### 3. Update Catalog Save Logic

Modify `editCatalogFromInput()` to save the sync_dir [4](#1-3) :

```lua
function OPDSBrowser:editCatalogFromInput(fields, item, no_refresh)
    local new_server = {
        title     = fields[1],
        url       = fields[2]:match("^%a+://") and fields[2] or "http://" .. fields[2],
        username  = fields[3] ~= "" and fields[3] or nil,
        password  = fields[4] ~= "" and fields[4] or nil,
        raw_names = fields[5],
        sync      = fields[6],
        sync_dir  = fields[7],  -- Add this line
    }
    -- Rest of function remains the same...
end
```

### 4. Update Download Directory Logic

Modify `getCurrentDownloadDir()` to check per-catalog folder first [5](#1-4) :

```lua
function OPDSBrowser:getCurrentDownloadDir(item)
    -- Check if we have a per-catalog sync directory
    if item and item.sync_dir then
        return item.sync_dir
    end
    -- Fall back to global sync directory
    if self.settings.sync_dir then
        return self.settings.sync_dir
    end
    -- Default download directory
    return self.download_dir
end
```

### 5. Update Sync Process

Modify the sync functions to use per-catalog folders. Update `checkSyncDownload()` [6](#1-5)  and related sync functions to pass the catalog item to download functions so they can use the correct directory.

## Notes

- The implementation adds a `sync_dir` field to each catalog configuration
- The folder selection button appears in the add/edit catalog dialog
- The download logic checks per-catalog folder first, then global, then default
- Existing catalogs without a sync_dir will continue using the global folder
- The sync process will need to be updated to pass catalog context to download operations

This implementation maintains backward compatibility while adding the requested per-catalog sync folder functionality.

### Citations

**File:** plugins/opds.koplugin/opdsbrowser.lua (L1-1)
```lua
local BD = require("ui/bidi")
```

**File:** plugins/opds.koplugin/opdsbrowser.lua (L211-229)
```lua
local function buildRootEntry(server)
    local icons = ""
    if server.username then
        icons = "\u{f2c0}"
    end
    if server.sync then
        icons = "\u{f46a} " .. icons
    end
    return {
        text       = server.title,
        mandatory  = icons,
        url        = server.url,
        username   = server.username,
        password   = server.password,
        raw_names  = server.raw_names, -- use server raw filenames for download
        searchable = server.url and server.url:match("%%s") and true or false,
        sync       = server.sync,
    }
end
```

**File:** plugins/opds.koplugin/opdsbrowser.lua (L245-313)
```lua
-- Shows dialog to edit properties of the new/existing catalog
function OPDSBrowser:addEditCatalog(item)
    local fields = {
        {
            hint = _("Catalog name"),
        },
        {
            hint = _("Catalog URL"),
        },
        {
            hint = _("Username (optional)"),
        },
        {
            hint = _("Password (optional)"),
            text_type = "password",
        },
    }
    local title
    if item then
        title = _("Edit OPDS catalog")
        fields[1].text = item.text
        fields[2].text = item.url
        fields[3].text = item.username
        fields[4].text = item.password
    else
        title = _("Add OPDS catalog")
    end

    local dialog, check_button_raw_names, check_button_sync_catalog
    dialog = MultiInputDialog:new{
        title = title,
        fields = fields,
        buttons = {
            {
                {
                    text = _("Cancel"),
                    id = "close",
                    callback = function()
                        UIManager:close(dialog)
                    end,
                },
                {
                    text = _("Save"),
                    callback = function()
                        local new_fields = dialog:getFields()
                        new_fields[5] = check_button_raw_names.checked or nil
                        new_fields[6] = check_button_sync_catalog.checked or nil
                        self:editCatalogFromInput(new_fields, item)
                        UIManager:close(dialog)
                    end,
                },
            },
        },
    }
    check_button_raw_names = CheckButton:new{
        text = _("Use server filenames"),
        checked = item and item.raw_names,
        parent = dialog,
    }
    check_button_sync_catalog = CheckButton:new{
        text = _("Sync catalog"),
        checked = item and item.sync,
        parent = dialog,
    }
    dialog:addWidget(check_button_raw_names)
    dialog:addWidget(check_button_sync_catalog)
    UIManager:show(dialog)
    dialog:onShowKeyboard()
end
```

**File:** plugins/opds.koplugin/opdsbrowser.lua (L350-375)
```lua
-- Saves catalog properties from input dialog
function OPDSBrowser:editCatalogFromInput(fields, item, no_refresh)
    local new_server = {
        title     = fields[1],
        url       = fields[2]:match("^%a+://") and fields[2] or "http://" .. fields[2],
        username  = fields[3] ~= "" and fields[3] or nil,
        password  = fields[4] ~= "" and fields[4] or nil,
        raw_names = fields[5],
        sync      = fields[6],
    }
    local new_item = buildRootEntry(new_server)
    local new_idx, itemnumber
    if item then
        new_idx = item.idx
        itemnumber = -1
    else
        new_idx = #self.servers + 2
        itemnumber = new_idx
    end
    self.servers[new_idx - 1] = new_server -- first item is "Downloads"
    self.item_table[new_idx] = new_item
    if not no_refresh then
        self:switchItemTable(nil, self.item_table, itemnumber)
    end
    self._manager.updated = true
end
```

**File:** plugins/opds.koplugin/opdsbrowser.lua (L989-995)
```lua
function OPDSBrowser:getCurrentDownloadDir()
    if self.sync then
        return self.settings.sync_dir
    else
        return G_reader_settings:readSetting("download_dir") or G_reader_settings:readSetting("lastdir")
    end
end
```

**File:** plugins/opds.koplugin/opdsbrowser.lua (L1507-1530)
```lua
function OPDSBrowser:checkSyncDownload(idx)
    if self.settings.sync_dir then
        self.sync = true
        local info = InfoMessage:new{
            text = _("Synchronizing lists…"),
        }
        UIManager:show(info)
        UIManager:forceRePaint()
        if idx then
            self:fillPendingSyncs(self.servers[idx-1]) -- First item is "Downloads"
        else
            for _, item in ipairs(self.servers) do
                if item.sync then
                    self:fillPendingSyncs(item)
                end
            end
        end
        UIManager:close(info)
        if #self.pending_syncs > 0 then
            Trapper:wrap(function()
                self:downloadPendingSyncs()
            end)
        else
            UIManager:show(InfoMessage:new{
```
