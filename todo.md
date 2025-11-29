you need to modify the showFacetMenu() function to include filter options and remove them from showOPDSMenu().

Move Filter Settings to Catalog Menu
Add the filter settings to showFacetMenu() opdsbrowser.lua:143-208 :

function OPDSBrowser:showFacetMenu()  
    local buttons = {}  
    local dialog  
    local catalog_url = self.paths[#self.paths].url  
  
    -- Add sub-catalog to bookmarks option first  
    table.insert(buttons, {{  
        text = "\u{f067} " .. _("Add catalog"),  
        callback = function()  
            UIManager:close(dialog)  
            self:addSubCatalog(catalog_url)  
        end,  
        align = "left",  
    }})  
    table.insert(buttons, {}) -- separator  
  
    -- Add filter settings  
    table.insert(buttons, {{  
        text = "\u{f0b0} " .. _("Set excluded authors"),  
        callback = function()  
            UIManager:close(dialog)  
            self:setExcludedAuthors()  
        end,  
        align = "left",  
    }})  
    table.insert(buttons, {{  
        text = "\u{f0b0} " .. _("Set excluded categories"),  
        callback = function()  
            UIManager:close(dialog)  
            self:setExcludedCategories()  
        end,  
        align = "left",  
    }})  
    table.insert(buttons, {{  
        text = "\u{f0b0} " .. _("Set included authors"),  
        callback = function()  
            UIManager:close(dialog)  
            self:setIncludedAuthors()  
        end,  
        align = "left",  
    }})  
    table.insert(buttons, {{  
        text = "\u{f0b0} " .. _("Set included categories"),  
        callback = function()  
            UIManager:close(dialog)  
            self:setIncludedCategories()  
        end,  
        align = "left",  
    }})  
    table.insert(buttons, {}) -- separator  
  
    -- Add search option if available  
    if self.search_url then  
        table.insert(buttons, {{  
            text = "\u{f002} " .. _("Search"),  
            callback = function()  
                UIManager:close(dialog)  
                self:searchCatalog(self.search_url)  
            end,  
            align = "left",  
        }})  
        table.insert(buttons, {}) -- separator  
    end  
  
    -- ... rest of existing facet groups code  
end
Remove Filter Settings from Home Menu
Remove the filter settings from showOPDSMenu() opdsbrowser.lua:77-140 by keeping only the global catalog management options:

function OPDSBrowser:showOPDSMenu()  
    local dialog  
    dialog = ButtonDialog:new{  
        buttons = {  
            {{  
                    text = _("Add catalog"),  
                    callback = function()  
                        UIManager:close(dialog)  
                        self:addEditCatalog()  
                    end,  
                    align = "left",  
            }},  
            {},  
            {{  
                    text = _("Sync all catalogs"),  
                    callback = function()  
                        UIManager:close(dialog)  
                        NetworkMgr:runWhenConnected(function()  
                            self.sync_force = false  
                            self:checkSyncDownload()  
                        end)  
                    end,  
                    align = "left",  
            }},  
            {{  
                    text = _("Force sync all catalogs"),  
                    callback = function()  
                        UIManager:close(dialog)  
                        NetworkMgr:runWhenConnected(function()  
                            self.sync_force = true  
                            self:checkSyncDownload()  
                        end)  
                    end,  
                    align = "left",  
            }},  
            {{  
                    text = _("Set max number of files to sync"),  
                    callback = function()  
                        self:setMaxSyncDownload()  
                    end,  
                    align = "left",  
            }},  
            {{  
                    text = _("Set sync folder"),  
                    callback = function()  
                        self:setSyncDir()  
                    end,  
                    align = "left",  
            }},  
            {{  
                    text = _("Set file types to sync"),  
                    callback = function()  
                        self:setSyncFiletypes()  
                    end,  
                    align = "left",  
            }},  
        },  
        shrink_unneeded_width = true,  
        anchor = function()  
            return self.title_bar.left_button.image.dimen  
        end,  
    }  
    UIManager:show(dialog)  
end
Notes
The filter settings are now only available when browsing a catalog (when showFacetMenu() is called) opdsbrowser.lua:726-730
The home page menu (showOPDSMenu()) now only contains global catalog management options
Filter settings use the \u{f0b0} filter icon to distinguish them from other menu items
The current catalog is identified using self.root_catalog_title opdsbrowser.lua:1087-1088 when the filter functions are called