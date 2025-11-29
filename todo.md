To set exclude filters per catalog instead of globally, you need to store the excluded authors and categories in each catalog's server properties rather than in the global settings. opdsbrowser.lua:211-229

Current Implementation
Your current code stores excluded filters in self.settings which applies to all catalogs globally.

Per-Catalog Solution
1. Modify the server structure to include exclude filters
Each server in self.servers already has properties like title, url, username, password, raw_names, and sync. opdsbrowser.lua:211-229 We'll add excluded_authors and excluded_categories:

-- In buildRootEntry function or when creating new servers  
local server = {  
    title = fields[1],  
    url = fields[2],  
    username = fields[3],  
    password = fields[4],  
    raw_names = fields[5],  
    sync = fields[6],  
    excluded_authors = fields[7],  -- New field  
    excluded_categories = fields[8], -- New field  
}
2. Update setExcludedAuthors to work with current catalog
function OPDSBrowser:setExcludedAuthors()  
    -- Find current server  
    local current_server = nil  
    for _, server in ipairs(self.servers) do  
        if server.title == self.root_catalog_title then  
            current_server = server  
            break  
        end  
    end  
      
    if not current_server then  
        UIManager:show(InfoMessage:new{text = _("No catalog selected")})  
        return  
    end  
      
    local current_excluded = table.concat(current_server.excluded_authors or {}, ", ")  
    local dialog  
    dialog = InputDialog:new{  
        title = _("Excluded Authors"),  
        description = _("Comma-separated list of authors to exclude"),  
        input_hint = _("Author One, Author Two"),  
        input = current_excluded,  
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
                    is_enter_default = true,  
                    callback = function()  
                        local input_text = dialog:getInputText()  
                        current_server.excluded_authors = {}  
                        for author in util.gsplit(input_text, ",") do  
                            table.insert(current_server.excluded_authors, util.trim(author))  
                        end  
                        self._manager.updated = true  
                        UIManager:close(dialog)  
                        if self.paths and #self.paths > 0 and self.paths[#self.paths] then  
                            self:updateCatalog(self.paths[#self.paths].url, true)  
                        end  
                    end,  
                },  
            },  
        },  
    }  
    UIManager:show(dialog)  
    dialog:onShowKeyboard()  
end
3. Update addEditCatalog to include exclude filter fields
Modify the addEditCatalog function to include input fields for exclude filters: opdsbrowser.lua:246-313

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
        {  
            hint = _("Excluded Authors (optional)"),  
        },  
        {  
            hint = _("Excluded Categories (optional)"),  
        },  
    }  
      
    if item then  
        fields[1].text = item.text  
        fields[2].text = item.url  
        fields[3].text = item.username  
        fields[4].text = item.password  
        fields[5].text = table.concat(item.excluded_authors or {}, ", ")  
        fields[6].text = table.concat(item.excluded_categories or {}, ", ")  
    end  
      
    -- ... rest of the function with updated field handling  
end
4. Update editCatalogFromInput to save the new fields
function OPDSBrowser:editCatalogFromInput(fields, item, no_refresh)  
    local new_server = {  
        title = fields[1],  
        url = fields[2]:match("^%a+://") and fields[2] or "http://" .. fields[2],  
        username = fields[3] ~= "" and fields[3] or nil,  
        password = fields[4] ~= "" and fields[4] or nil,  
        raw_names = fields[5],  
        sync = fields[6],  
        excluded_authors = {},  
        excluded_categories = {},  
    }  
      
    -- Parse excluded authors  
    if fields[7] and fields[7] ~= "" then  
        for author in util.gsplit(fields[7], ",") do  
            table.insert(new_server.excluded_authors, util.trim(author))  
        end  
    end  
      
    -- Parse excluded categories  
    if fields[8] and fields[8] ~= "" then  
        for category in util.gsplit(fields[8], ",") do  
            table.insert(new_server.excluded_categories, util.trim(category))  
        end  
    end  
      
    -- ... rest of the function  
end
Notes
The self.root_catalog_title variable is set when you enter a catalog and can be used to identify the current catalog opdsbrowser.lua:1087-1088
Your custom exclude filter functions are not part of the actual koreader codebase opdsbrowser.lua:77-140
The per-catalog settings will be saved in the opds.lua file as part of each server's configuration main.lua:47-58