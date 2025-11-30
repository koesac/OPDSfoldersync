The Problem
In checkSyncDownload(), the last_sync_time is only updated in the "else" branch (when no downloads are needed), but not when #self.pending_syncs > 0 opdsbrowser.lua:1525-1533 . This means:

Auto-sync starts and finds books to download
Downloads begin but last_sync_time stays at old value
Periodic sync checks and thinks it's time to sync again
Creates infinite loop of sync attempts
Solution
Update checkSyncDownload() to set last_sync_time after downloads complete:

function OPDSBrowser:checkSyncDownload(idx)  
    if self.settings.sync_dir then  
        self.sync = true  
        local info = InfoMessage:new{  
            text = _("Synchronizing lists…"),  
        }  
        UIManager:show(info)  
        UIManager:forceRePaint()  
        if idx then  
            self:fillPendingSyncs(self.servers[idx-1])  
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
                -- Update last sync time after successful downloads  
                self.settings.last_sync_time = os.time()  
                self._manager.updated = true  
                self._manager:saveSettings()  
            end)  
        else  
            UIManager:show(InfoMessage:new{  
                text = _("Up to date!"),  
            })  
            -- Update last sync time even if nothing new  
            self.settings.last_sync_time = os.time()  
            self._manager.updated = true  
        end  
        self.sync = false  
    else  
        UIManager:show(InfoMessage:new{  
            text = _("Please choose a folder for sync downloads first"),  
        })  
    end  
end
Additional Fix - Prevent Concurrent Syncs
Add sync state tracking in main.lua :

function OPDS:performAutoSync()  
    if self.sync_in_progress then  
        logger.dbg("OPDS: Sync already in progress, skipping")  
        return  
    end  
      
    -- ... existing checks ...  
      
    self.sync_in_progress = true  
    logger.dbg("OPDS: Starting auto-sync")  
      
    if self.opds_browser then  
        self.opds_browser.sync_force = false  
        self.opds_browser:checkSyncDownload()  
    end  
      
    self.sync_in_progress = false  
end
Notes
The key issue is that downloadPendingSyncs() doesn't update last_sync_time, so the auto-sync scheduler keeps triggering. By updating the timestamp after downloads complete and adding state tracking to prevent concurrent syncs, the loop should be resolved. opdsbrowser.lua:1676-1697