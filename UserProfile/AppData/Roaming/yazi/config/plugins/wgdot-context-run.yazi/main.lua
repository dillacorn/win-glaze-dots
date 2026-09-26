--- @sync entry

return {
    entry = function(_, job)
        if not WgdotYaziContextMenu or type(WgdotYaziContextMenu.choose) ~= "function" then
            ya.notify {
                title = "Yazi",
                content = "WGDot context action runner is unavailable.",
                timeout = 3,
                level = "error",
            }
            return
        end

        if job.args.cancel then
            WgdotYaziContextMenu:choose(nil)
            return
        end

        WgdotYaziContextMenu:choose(tonumber(job.args.index))
    end,
}
