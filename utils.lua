local utils = {}

function utils.RGBA2HSVA(r, g, b, a)
    local Cmax = math.max(r, g, b)
    local Cmin = math.min(r, g, b)
    local dC = Cmax - Cmin
    local H =   dC == 0 and 0 or
                Cmax == r and 60*((g-b)/dC)%6 or
                Cmax == g and 60*((b-r)/dC+2) or
                Cmax == b and 60*((r-g)/dC+4)
    local S =   Cmax == 0 and 0 or  dC/Cmax
    local V = Cmax
    return {H, S, V, a}
end

function utils.HSA(h, s, a)
	-- find a colour from hue and saturation
	h = (h%360)/60
	local i, f, g, t
	i, f = math.modf(h)
	g = 1-f -- for descending gradients
	t = 1-s -- min colour intensity based on saturation
	f, g = s*f+t, s*g+t -- apply saturation to the gradient values
		if i == 0 then return {1, f, t, a}
	elseif i == 1 then return {g, 1, t, a}
	elseif i == 2 then return {t, 1, f, a}
	elseif i == 3 then return {t, g, 1, a}
	elseif i == 4 then return {f, t, 1, a}
	elseif i == 5 then return {1, t, g, a}
	else return {1, 1, 1, a}
	end
end

function utils.HSVA(h, s, v, a)
	-- apply value to the hue/saturation colour
	local c = utils.HSA(h, s, a or 1)
	for i = 1, 3 do c[i] = c[i]*v end
	return c
end

function utils.Hue(h, a)
    return utils.HSA(h, 200/255, a or 1)
end

function utils.deepcopy(orig)
	local copy
	if type(orig) == "table" then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			if orig_value ~= orig then
				copy[utils.deepcopy(orig_key)] = utils.deepcopy(orig_value)
			end
		end
		setmetatable(copy, utils.deepcopy(getmetatable(orig)))
	else
		copy = orig
	end
	return copy
end

function utils.tablePrint(vTable, vTab)
	local tab = vTab or ""
	if type(vTable) ~= "table" then return end

	for i, v in pairs(vTable) do
		print(tab..tostring(i), v)
		if type(v) == "table" and v ~= vTable then
			utils.tablePrint(v, tab.."\t")
		end
	end
end

function utils.clamp(val, min, max)
	if min > max then
		min, max = max, min
	end
	return math.min(math.max(val, min), max)
end

function utils.invLerp(a, b, t)
	return (t-a) / (b-a)
end

return utils