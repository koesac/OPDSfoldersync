Server Structure Extension
Add included_authors and included_categories to your server configuration alongside the existing exclude fields:

local server = {  
    title = fields[1],  
    url = fields[2],  
    username = fields[3],  
    password = fields[4],  
    raw_names = fields[5],  
    sync = fields[6],  
    excluded_authors = fields[7],  
    excluded_categories = fields[8],  
    included_authors = fields[9],  -- New field  
    included_categories = fields[10], -- New field  
}
Update addEditCatalog Function
Extend the fields array in addEditCatalog opdsbrowser.lua:246-313 :

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
    {  
        hint = _("Included Authors (optional)"),  
    },  
    {  
        hint = _("Included Categories (optional)"),  
    },  
}
Update editCatalogFromInput Function
Add parsing for the new include fields:

local new_server = {  
    title = fields[1],  
    url = fields[2]:match("^%a+://") and fields[2] or "http://" .. fields[2],  
    username = fields[3] ~= "" and fields[3] or nil,  
    password = fields[4] ~= "" and fields[4] or nil,  
    raw_names = fields[5],  
    sync = fields[6],  
    excluded_authors = {},  
    excluded_categories = {},  
    included_authors = {},  
    included_categories = {},  
}  
  
-- Parse included authors  
if fields[9] and fields[9] ~= "" then  
    for author in util.gsplit(fields[9], ",") do  
        table.insert(new_server.included_authors, util.trim(author))  
    end  
end  
  
-- Parse included categories  
if fields[10] and fields[10] ~= "" then  
    for category in util.gsplit(fields[10], ",") do  
        table.insert(new_server.included_categories, util.trim(category))  
    end  
end
Add Include Filter Functions
Create setIncludedAuthors and setIncludedCategories functions following the same pattern as your setExcludedAuthors function:

function OPDSBrowser:setIncludedAuthors()  
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
      
    local current_included = table.concat(current_server.included_authors or {}, ", ")  
    local dialog  
    dialog = InputDialog:new{  
        title = _("Included Authors"),  
        description = _("Comma-separated list of authors to include"),  
        input_hint = _("Author One, Author Two"),  
        input = current_included,  
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
                        current_server.included_authors = {}  
                        for author in util.gsplit(input_text, ",") do  
                            table.insert(current_server.included_authors, util.trim(author))  
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
Menu Integration
Add menu items to showOPDSMenu opdsbrowser.lua:77-140 :

{{  
    text = _("Set included authors"),  
    callback = function()  
        self:setIncludedAuthors()  
    end,  
    align = "left",  
}},  
{{  
    text = _("Set included categories"),  
    callback = function()  
        self:setIncludedCategories()  
    end,  
    align = "left",  
}},
Notes
The include filters will be saved in the opds.lua settings file through the existing self._manager.updated = true mechanism main.lua:47-58
You'll need to implement the filtering logic that uses both include and exclude lists when processing catalog entries
The current catalog identification using self.root_catalog_title works the same way for include filters opdsbrowser.lua:1087-1088
Consider the interaction between include and exclude filters in your filtering logic (e.g., if both are set, which takes precedence)