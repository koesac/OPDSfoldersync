I'll help you replace the "n books downloaded" InfoMessage with the basic Notification pattern.

Current Implementation
The download notifications currently use InfoMessage in two places:

In downloadPendingSyncs() - Shows count after sync downloads opdsbrowser.lua:1730-1732
In downloadDownloadList() - Shows count after manual download list opdsbrowser.lua:1410-1415
Solution
Replace both InfoMessage calls with the Notification pattern:

1. Update downloadPendingSyncs()
function OPDSBrowser:downloadPendingSyncs(auto_sync)  
    -- ... existing code ...  
      
    if dl_count > 0 then  
        UIManager:show(Notification:new{  
            text = T(N_("1 book downloaded", "%1 books downloaded", dl_count), dl_count)  
        })  
    end  
    self._manager.updated = true  
    return duplicate_list  
end
2. Update downloadDownloadList()
function OPDSBrowser:downloadDownloadList()  
    -- ... existing code ...  
      
    if dl_count > 0 then  
        self:updateDownloadListItemTable()  
        self.download_list_updated = true  
        self._manager.updated = true  
        UIManager:show(Notification:new{  
            text = T(N_("1 book downloaded", "%1 books downloaded", dl_count), dl_count)  
        })  
    end  
end
Notes
The Notification widget is already imported at the top of opdsbrowser.lua opdsbrowser.lua:13
This change affects both auto-sync and manual download operations
The Notification widget has a default 2-second timeout, which is appropriate for download confirmations
No need to pass the timeout parameter since Notification handles timing automatically notification.lua:61




