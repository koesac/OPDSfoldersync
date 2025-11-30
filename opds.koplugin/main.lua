local BD = require("ui/bidi")
local ConfirmBox = require("ui/widget/confirmbox")
local DataStorage = require("datastorage")
local Dispatcher = require("dispatcher")
local LuaSettings = require("luasettings")
local OPDSBrowser = require("opdsbrowser")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local util = require("util")
local _ = require("gettext")
local T = require("ffi/util").template
local logger = require("logger")

local OPDS = WidgetContainer:extend{
    name = "opds",
    opds_settings_file = DataStorage:getSettingsDir() .. "/opds.lua",
    settings = nil,
    servers = nil,
    downloads = nil,
    -- Add auto-sync task reference
    periodic_sync_task = nil,
    default_servers = {
        {
            title = "Project Gutenberg",
            url = "https://m.gutenberg.org/ebooks.opds/?format=opds",
        },
        {
            title = "Standard Ebooks",
            url = "https://standardebooks.org/feeds/opds",
        },
        {
            title = "ManyBooks",
            url = "http://manybooks.net/opds/index.php",
        },
        {
            title = "Internet Archive",
            url = "https://bookserver.archive.org/",
        },
        {
            title = "textos.info (Spanish)",
            url = "https://www.textos.info/catalogo.atom",
        },
        {
            title = "Gallica (French)",
            url = "https://gallica.bnf.fr/opds",
        },
    },
    -- Add default settings with auto-sync enabled
    default_settings = {
        sync_dir = nil,
        sync_max_dl = 50,
        filetypes = nil,
        -- Auto-sync settings with defaults
        auto_sync = true,           -- Enabled by default
        sync_interval_hours = 24,   -- Sync every 24 hours
        sync_on_network = true,     -- Sync when network connects
        sync_on_resume = true,      -- Sync when resuming from sleep
        last_sync_time = 0,         -- Track last sync time
    },
}

function OPDS:init()
    self.opds_settings = LuaSettings:open(self.opds_settings_file)
    if next(self.opds_settings.data) == nil then
        self.updated = true -- first run, force flush
    end
    self.servers = self.opds_settings:readSetting("servers", self.default_servers)
    self.downloads = self.opds_settings:readSetting("downloads", {})
    -- Initialize settings with defaults
    self.settings = self.opds_settings:readSetting("settings", self.default_settings)
    -- Ensure all default settings are present
    for k, v in pairs(self.default_settings) do
        if self.settings[k] == nil then
            self.settings[k] = v
            self.updated = true
        end
    end
    self.pending_syncs = self.opds_settings:readSetting("pending_syncs", {})
    self.sync_in_progress = false

    -- Initialize auto-sync
    self:initAutoSync()

    self:onDispatcherRegisterActions()
    self.ui.menu:registerToMainMenu(self)
end

function OPDS:onDispatcherRegisterActions()
    Dispatcher:registerAction("opds_show_catalog",
        {category="none", event="ShowOPDSCatalog", title=_("OPDS Catalog"), filemanager=true,}
    )
end

function OPDS:addToMainMenu(menu_items)
    if not self.ui.document then -- FileManager menu only
        menu_items.opds = {
            text = _("OPDS catalog"),
            callback = function()
                self:onShowOPDSCatalog()
            end,
        }
    end
end

function OPDS:onShowOPDSCatalog()
    self.opds_browser = OPDSBrowser:new{
        servers = self.servers,
        downloads = self.downloads,
        settings = self.settings,
        pending_syncs = self.pending_syncs,
        title = _("OPDS catalog"),
        is_popout = false,
        is_borderless = true,
        title_bar_fm_style = true,
        _manager = self,
        file_downloaded_callback = function(file)
            self:showFileDownloadedDialog(file)
        end,
        close_callback = function()
            if self.opds_browser.download_list then
                self.opds_browser.download_list.close_callback()
            end
            UIManager:close(self.opds_browser)
            self.opds_browser = nil
            if self.last_downloaded_file then
                if self.ui.file_chooser then
                    local pathname = util.splitFilePathName(self.last_downloaded_file)
                    self.ui.file_chooser:changeToPath(pathname, self.last_downloaded_file)
                end
                self.last_downloaded_file = nil
            end
        end,
    }
    UIManager:show(self.opds_browser)
end

function OPDS:showFileDownloadedDialog(file)
    self.last_downloaded_file = file
    UIManager:show(ConfirmBox:new{
        text = T(_("File saved to:\n%1\nWould you like to read the downloaded book now?"), BD.filepath(file)),
        ok_text = _("Read now"),
        ok_callback = function()
            self.last_downloaded_file = nil
            self.opds_browser.close_callback()
            if self.ui.document then
                self.ui:switchDocument(file)
            else
                self.ui:openFile(file)
            end
        end,
    })
end

function OPDS:initAutoSync()
    -- Create periodic sync task
    self.periodic_sync_task = function()
        logger.info("OPDS: Running periodic sync check")
        self:performAutoSync()
        self:schedulePeriodicSync() 
    end

    -- Schedule initial sync
    if self.settings.auto_sync then
        self:schedulePeriodicSync()
        self:registerAutoSyncEvents()
    end
end

function OPDS:registerAutoSyncEvents()
    if self.settings.auto_sync then
        self.onNetworkConnected = self._onNetworkConnected
        self.onResume = self._onResume
    else
        self.onNetworkConnected = nil
        self.onResume = nil
    end
end

function OPDS:_onNetworkConnected()
    logger.info("OPDS: Network connected, checking auto-sync")
    if self.settings.sync_on_network then
        UIManager:scheduleIn(0.5, function()
            self:performAutoSync()
        end)
    end
end

function OPDS:_onResume()
    logger.info("OPDS: Resumed, checking auto-sync")
    if self.settings.sync_on_resume then
        UIManager:scheduleIn(2, function()
            self:performAutoSync()
        end)
    end
end

function OPDS:schedulePeriodicSync()
    UIManager:unschedule(self.periodic_sync_task)
    local interval_seconds = self.settings.sync_interval_hours * 3600
    UIManager:scheduleIn(interval_seconds, self.periodic_sync_task)
    logger.info("OPDS: Scheduled periodic sync in", interval_seconds, "seconds")
end

function OPDS:performAutoSync()
    if self.sync_in_progress then
        logger.info("OPDS: Sync already in progress, skipping")
        return
    end
    -- Check if we have a sync directory configured
    if not self.settings.sync_dir then
        logger.info("OPDS: No sync directory configured, skipping auto-sync")
        return
    end

    -- Check if enough time has passed since last sync
    local now = os.time()
    local time_since_last = now - (self.settings.last_sync_time or 0)
    local min_interval = self.settings.sync_interval_hours * 3600

    if time_since_last < min_interval then
        logger.info("OPDS: Last sync too recent, skipping")
        return
    end

    -- Check network connectivity
    local NetworkMgr = require("ui/network/manager")
    if not NetworkMgr:isOnline() then
        logger.info("OPDS: Not online, skipping auto-sync")
        return
    end

    self.sync_in_progress = true
    logger.info("OPDS: Starting auto-sync")

    -- Wrap sync in a protected call
    local success, err = pcall(function()
        -- Create browser instance if it doesn't exist
        if not self.opds_browser then
            self.opds_browser = OPDSBrowser:new{
                servers = self.servers,
                downloads = self.downloads,
                settings = self.settings,
                pending_syncs = self.pending_syncs,
                title = _("OPDS catalog"),
                is_popout = false,
                is_borderless = true,
                title_bar_fm_style = true,
                _manager = self,
            }
        end
        self.opds_browser.sync_force = false
        self.opds_browser:checkSyncDownload()
    end)

    self.sync_in_progress = false

    if success then
        self.settings.last_sync_time = now
        self.updated = true
        self:saveSettings()
    else
        logger.err("OPDS: Auto-sync failed:", err)
    end
end

function OPDS:saveSettings()
    if self.updated then
        self.opds_settings:saveSetting("servers", self.servers)
        self.opds_settings:saveSetting("downloads", self.downloads)
        self.opds_settings:saveSetting("settings", self.settings)
        self.opds_settings:saveSetting("pending_syncs", self.pending_syncs)
        self.opds_settings:flush()
        self.updated = false
    end
end

function OPDS:onCloseWidget()
    UIManager:unschedule(self.periodic_sync_task)
    self:saveSettings()
end

return OPDS
