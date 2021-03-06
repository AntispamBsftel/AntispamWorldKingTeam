local function cron()
	local all = db:hgetall('tempbanned')
	if next(all) then
		for unban_time,info in pairs(all) do
			if os.time() > tonumber(unban_time) then
				local chat_id, user_id = info:match('(-%d+):(%d+)')
				api.unbanUser(chat_id, user_id, true)
				api.unbanUser(chat_id, user_id, false)
				db:hdel('tempbanned', unban_time)
				db:srem('chat:'..chat_id..':tempbanned', user_id) --hash needed to check if an user is already tempbanned or not
			end
		end
	end
end

local function check_valid_time(temp)
	temp = tonumber(temp)
	if temp == 0 then
		return false, 1
	elseif temp > 10080 then --1 week
		return false, 2
	else
		return temp
	end
end

local function get_time_reply(minutes)
	local time_string = ''
	local time_table = {}
	time_table.days = math.floor(minutes/(60*24))
	minutes = minutes - (time_table.days*60*24)
	time_table.hours = math.floor(minutes/60)
	time_table.minutes = minutes % 60
	if not(time_table.days == 0) then
		time_string = time_table.days..'d'
	end
	if not(time_table.hours == 0) then
		time_string = time_string..' '..time_table.hours..'h'
	end
	time_string = time_string..' '..time_table.minutes..'m'
	return time_string, time_table
end

local action = function(msg, blocks)
	if msg.chat.type ~= 'private' then
		if roles.is_admin_cached(msg) then
		    
		    local user_id, error_translation_key = misc.get_user_id(msg, blocks)
		    
		    if not user_id then
		    	api.sendReply(msg, _(error_translation_key), true) return
		    end
		    if msg.reply and msg.reply.from.id == bot.id then return end
		 	
		 	local res
		 	local chat_id = msg.chat.id
		 	local admin, kicked = misc.getnames_complete(msg, blocks)
		 	
		 	if blocks[1] == 'tempban' then
				if not msg.reply then
					api.sendReply(msg, _("Reply to someone"))
					return
				end
				local user_id = msg.reply.from.id
				local temp, code = check_valid_time(blocks[2])
				if not temp then
					if code == 1 then
						api.sendReply(msg, _("For this, you can directly use /ban"))
					else
						api.sendReply(msg, _("The time limit is one week (10 080 minutes)"))
					end
					return
				end
				local val = msg.chat.id..':'..user_id
				local unban_time = os.time() + (temp * 60)
				
				--try to kick
				local res, motivation = api.banUser(chat_id, user_id)
		    	if not res then
		    		if not motivation then
		    			motivation = _("I can't kick this user.\n"
								.. "Probably I'm not an Amdin, or the user is an Admin iself")
		    		end
		    		api.sendReply(msg, motivation, true)
		    	else
		    		misc.saveBan(user_id, 'tempban') --save the ban
		    		db:hset('tempbanned', unban_time, val) --set the hash
					local time_reply = get_time_reply(temp)
					local is_already_tempbanned = db:sismember('chat:'..chat_id..':tempbanned', user_id) --hash needed to check if an user is already tempbanned or not
					local text
					if is_already_tempbanned then
						text = _("Ban time updated for %s. Ban expiration: %s"):format(banned_name, time_reply)
					else
						text = _("User %s banned. Ban expiration: %s"):format(kicked, time_reply)
						db:sadd('chat:'..chat_id..':tempbanned', user_id) --hash needed to check if an user is already tempbanned or not
					end
					api.sendMessage(chat_id, text)
				end
			end
		 	if blocks[1] == 'kick' then
		    	local res, motivation = api.kickUser(chat_id, user_id)
		    	if not res then
		    		if not motivation then
		    			motivation = _("I can't kick this user.\n"
								.. "Probably I'm not an Amdin, or the user is an Admin iself")
		    		end
		    		api.sendReply(msg, motivation, true)
		    	else
		    		misc.saveBan(user_id, 'kick')
		    		api.sendMessage(msg.chat.id, _("%s kicked %s!"):format(admin, kicked), true)
		    	end
	    	end
	   		if blocks[1] == 'ban' then
	   			local res, motivation = api.banUser(chat_id, user_id)
		    	if not res then
		    		if not motivation then
		    			motivation = _("I can't kick this user.\n"
								.. "Probably I'm not an Amdin, or the user is an Admin iself")
		    		end
		    		api.sendReply(msg, motivation, true)
		    	else
		    		--save the ban
		    		misc.saveBan(user_id, 'ban')
		    		local why
		    		if msg.reply then
		    			why = msg.text:input()
		    		else
		    			why = msg.text:gsub(config.cmd..'ban @[%w_]+%s?', '')
		    		end
		    		--misc.logEvent('ban', msg, blocks, 'cnhdc cbhdhcbhcd bcdhcdbc')
		    		api.sendMessage(msg.chat.id, _("%s banned %s!"):format(admin, kicked), true)
		    	end
    		end
   			if blocks[1] == 'unban' then
   				api.unbanUser(chat_id, user_id)
   				local text = _("User unbanned by %s!"):format(admin)
   				api.sendReply(msg, text, true)
   			end
		else
			if blocks[1] == 'kickme' then
				api.kickUser(msg.chat.id, msg.from.id)
			end
		end
	end
end

return {
	action = action,
	cron = cron,
	triggers = {
		config.cmd..'(kickme)%s?',
		config.cmd..'(kick) (.+)',
		config.cmd..'(kick)$',
		config.cmd..'(ban) (.+)',
		config.cmd..'(ban)$',
		config.cmd..'(tempban) (%d+)',
		config.cmd..'(unban) (.+)',
		config.cmd..'(unban)$',
	}
}
