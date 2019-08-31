-- the global addon table, with basic general variables
QuestWatcherAddon = {
    CurrentLocation = "",
    CurrentAreaID = 0,
    TotalQuestsWatched = 0,
    TotalCompletedQuests = 0,
    FontPath = "Fonts\\FRIZQT__.TTF",
    FontSize = 12
};

local qw = QuestWatcherAddon;

-- create the addon UI frame (current location, number quests, and completed quests)
qw.ParentFrame = CreateFrame("Frame", nil, UIParent);
qw.LocationFrame = CreateFrame("Frame", nil, qw.ParentFrame);
qw.QuestsFrame = CreateFrame("Frame", nil, qw.ParentFrame);

-- events to register when the addon is loaded
function qw.OnLoadEvents(self)
    -- register events
    self:RegisterEvent("ADDON_LOADED");
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA");
    self:RegisterEvent("UNIT_QUEST_LOG_CHANGED");

    -- build the UI frame
    qw.InitParentFrame();
    qw.InitLocationFrame();
    qw.InitQuestFrame();

    -- register slash commands
    SLASH_QUESTWATCHER1 = '/questwatcher';
    SLASH_QUESTWATCHER2 = '/qw';
    SlashCmdList["QUESTWATCHER"] = qw.QuestWatcher_SlashHandler;
end

-- deal with slash commands for the addon
function qw.QuestWatcher_SlashHandler(msg, editbox)
    -- show frame
    if (msg == 'show') then
        qw.ParentFrame:Show();
        print("QuestWatcher frame is now being displayed.");
    end

    -- hide frame
    if (msg == 'hide') then
        qw.ParentFrame:Hide();
        print("QuestWatcher frame hidden.");
    end

    -- prints the current area ID to chat
    if (msg == 'id') then
        local _id = qw.GetAreaID();
        print("Current Area ID: " .. _id);

        local _message = qw.GetAreaName(_id);
        print("Current Area Name: " .. _message);
    end

    -- prints the quests for the current area
    if (msg == 'list') then
        local quests = qw.GetCurrentAreaQuests();
        local _progress = quests.InProgress;
        local _completed = quests.Completed;

        print("Quests for " .. qw.CurrentLocation);

        for index = 1, #_progress do
            print("> " .. _progress[index].Name);
        end

        for index = 1, #_completed do
            print("> " .. _completed[index].Name .. " [completed]");
        end
    end

    -- display help info (commands)
    if (msg == 'help') then
        print("QuestWatcher command help.");
        print("Type either /qw or /questwatcher, followed by:");
        print("   show - displays the moveable frame.");
        print("   hide - hides the moveable frame.");
        print("   id - displays current area name/id.");
        print("   help - what you're reading now...");
    end
end

-- initialise the parent UI frame
function qw.InitParentFrame()
    qw.ParentFrame:SetWidth(300)
    qw.ParentFrame:SetHeight(80)
    qw.ParentFrame:SetPoint("BOTTOMLEFT", 30, 30)
    qw.ParentFrame:Show()

    -- movability
    qw.ParentFrame:SetMovable(true)
    qw.ParentFrame:EnableMouse(true)

    qw.ParentFrame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" and not self.isMoving then
            self:StartMoving();
            self.isMoving = true;
        end
    end)

    qw.ParentFrame:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.isMoving then
            qw.ParentFrame:SetUserPlaced(true);
            self:StopMovingOrSizing();
            self.isMoving = false;
        end
    end)
end

-- initialise the location UI frame
function qw.InitLocationFrame()
    qw.LocationFrame:SetWidth(300)
    qw.LocationFrame:SetHeight(26)
    qw.LocationFrame:SetPoint("TOPLEFT", 0, 0)
    qw.LocationFrame:Show()

    -- set it's font
    qw.LocationFrame = qw.LocationFrame:CreateFontString("LocationFrameText", "OVERLAY", "GameTooltipText")
    qw.LocationFrame:SetAllPoints()
    LocationFrameText:SetFont(qw.FontPath, qw.FontSize, "OUTLINE")
    qw.LocationFrame:Show()
    qw.LocationFrame:SetText("0")
end

-- initialise the quests UI frame
function qw.InitQuestFrame()
    qw.QuestsFrame:SetWidth(300)
    qw.QuestsFrame:SetHeight(26)
    qw.QuestsFrame:SetPoint("TOPLEFT", 0, -27)
    qw.QuestsFrame:Show()

    --set it's font
    qw.QuestsFrame = qw.QuestsFrame:CreateFontString("QuestsFrameText", "OVERLAY", "GameTooltipText")
    qw.QuestsFrame:SetAllPoints()
    QuestsFrameText:SetFont(qw.FontPath, qw.FontSize, "OUTLINE")
    qw.QuestsFrame:Show()
    qw.QuestsFrame:SetText("0")
end

-- get the current area's ID
function qw.GetAreaID()
    return C_Map.GetBestMapForUnit("player");
end

-- get required area name, given an areaId
function qw.GetAreaName(areaId)
    if (areaId == nil) then
        areaId = qw.CurrentAreaID;
    end

    local info = C_Map.GetMapInfo(areaId)
    if (info == nil) then
        return "";
    end

    return info.name;
end

-- is the player on a contintent?
function qw.IsPlayerOnContinent(areaId)
    if (areaId == nil) then
        areaId = qw.CurrentAreaID;
    end

    local info = C_Map.GetMapInfo(areaId)
    if (info == nil) then
        return false;
    end

    return (info.type == "Continent");
end

-- set the location frame's text
function qw.SetLocationFrameText()
    qw.LocationFrame:SetText("Loc: " .. qw.CurrentLocation .. "  (" .. qw.CurrentAreaID .. ")");
end

-- set the quest frame's text
function qw.SetQuestsFrameText()
    if (qw.TotalCompletedQuests > 0) then
        qw.QuestsFrame:SetText("Qst: " .. qw.TotalQuestsWatched .. " (" .. qw.TotalCompletedQuests .. " completed)");
    else
        qw.QuestsFrame:SetText("Qst: " .. qw.TotalQuestsWatched);
    end
end

-- set the player's current location
function qw.SetPlayerCurrentLocation()
    local _playerAreaID = qw.GetAreaID();
    local _playerLocation = qw.GetAreaName(_playerAreaID);

    if (_playerLocation == qw.CurrentLocation) then
        return false;
    end

    qw.CurrentAreaID = _playerAreaID;
    qw.CurrentLocation = _playerLocation;
    return true;
end

-- get a list of quests for the current area
function qw.GetCurrentAreaQuests()
    local quests = {
        InProgress = {},
        Completed = {},
        Counts = {}
    };

    local index = 1;
    local inProgressIndex = 1;
    local completedIndex = 1;
    local watch = false;

    -- loop to get all quests for current area
    while GetQuestLogTitle(index) do
        local questTitle, level, suggestedGroup, isHeader, isCollapsed, isComplete = GetQuestLogTitle(index);

        --if we have a header, see if it's equal to where the player is located
        if (isHeader) then
            if (watch) then
                break;
            end

            watch = (questTitle == qw.CurrentLocation);

        -- else we have a quest, is it watchable?
        else
            if (watch) then
                -- the quest is completed
                if (isComplete ~= nil) then
                    SelectQuestLogEntry(index);
                    quests.Completed[completedIndex] = {
                        Name = questTitle,
                        Index = index
                    }
                    completedIndex = completedIndex + 1;

                -- the quest is in-progess
                else
                    quests.InProgress[inProgressIndex] = {
                        Name = questTitle,
                        Index = index
                    }
                    inProgressIndex = inProgressIndex + 1;
                end
            end
        end

        -- increment the index
        index = index + 1;
    end

    -- add total counts
    quests.Counts.InProgress = inProgressIndex - 1;
    quests.Counts.Completed = completedIndex - 1;
    return quests;
end

-- unwatch all quests
function qw.UnwatchAllQuests()
    local index = 1;

    while GetQuestLogTitle(index) do
        local questTitle, level, suggestedGroup, isHeader = GetQuestLogTitle(index);
        if (not isHeader) then
            RemoveQuestWatch(index);
        end
        index = index + 1;
    end
end

-- main entry event
function qw.OnEventHandler(self, event, ...)
    -- expand all quest headers
    ExpandQuestHeader(0);

    -- intialise local variables
    local _watch = false;
    local _totalQuestsWatched = 0;
    local _totalCompletedQuests = 0;
    local _questMsg = true;
    local _completedMsg = true;

    -- get the player's current area location
    local _areaChanged = qw.SetPlayerCurrentLocation();
    if (_areaChanged == nil) then
        return true;
    end

    -- has the player entered a new area? if so, make this their CurrentLocation
    if (_areaChanged) then
        print("ID: " .. qw.CurrentAreaID);
        print("Location: " .. qw.CurrentLocation .. " (" .. qw.CurrentAreaID .. ")");

        -- set the location frame
        if (not qw.IsPlayerOnContinent(nil)) then
            qw.SetLocationFrameText();
        end
    else
        _questMsg = false;
        _completedMsg = false;
    end

    -- if the player has entered a new Continent, then don't scan for quests (as there aren't any...)
    if (qw.IsPlayerOnContinent(nil)) then
        return true;
    end

    -- unwatch all quests
    qw.UnwatchAllQuests();

    -- get current quests
    local _quests = qw.GetCurrentAreaQuests();

    -- watch in-progress quests
    for index = 1, #_quests.InProgress do
        AddQuestWatch(_quests.InProgress[index].Index);
    end

    qw.TotalQuestsWatched = _quests.Counts.InProgress;
    qw.TotalCompletedQuests = _quests.Counts.Completed;

    -- tell the user how many quests are currently being watched
    if (_questMsg) then
        if (qw.TotalQuestsWatched == 1) then
            RaidNotice_AddMessage(RaidWarningFrame, qw.TotalQuestsWatched .. " quest is now being tracked.", ChatTypeInfo["RAID_WARNING"])
        else
            if (qw.TotalQuestsWatched > 1) then
                RaidNotice_AddMessage(RaidWarningFrame, qw.TotalQuestsWatched .. " quests are now being tracked.", ChatTypeInfo["RAID_WARNING"])
                
            else
                RaidNotice_AddMessage(RaidWarningFrame, "You have no quests in this area.", ChatTypeInfo["RAID_WARNING"])
            end
        end
    end

    -- how many quests are completed?
    if (_completedMsg) then
        if (qw.TotalCompletedQuests == 1) then
            RaidNotice_AddMessage(RaidWarningFrame, "With " .. qw.TotalCompletedQuests .. " completed quest.", ChatTypeInfo["RAID_WARNING"])
        else
            if (qw.TotalCompletedQuests > 1) then
                RaidNotice_AddMessage(RaidWarningFrame, "With " .. qw.TotalCompletedQuests .. " completed quests.", ChatTypeInfo["RAID_WARNING"])
                
            else
                RaidNotice_AddMessage(RaidWarningFrame, "With no completed quests in this area.", ChatTypeInfo["RAID_WARNING"])
            end
        end
    end

    qw.SetQuestsFrameText();
end