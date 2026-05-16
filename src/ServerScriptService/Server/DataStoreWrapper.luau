--!nonstrict
-- DataStore access with exponential-backoff retries. Every store call in the
-- game goes through here so failures are handled in exactly one place.

local DataStoreWrapper = {}

local MAX_ATTEMPTS = 4

local function retry(fn: () -> any): (boolean, any)
	local ok, res
	for attempt = 1, MAX_ATTEMPTS do
		ok, res = pcall(fn)
		if ok then
			return true, res
		end
		warn(`[DataStoreWrapper] attempt {attempt}/{MAX_ATTEMPTS} failed: {tostring(res)}`)
		if attempt < MAX_ATTEMPTS then
			task.wait(2 ^ (attempt - 1)) -- 1s, 2s, 4s
		end
	end
	return false, res
end

function DataStoreWrapper.get(store, key: string): (boolean, any)
	return retry(function()
		return store:GetAsync(key)
	end)
end

function DataStoreWrapper.set(store, key: string, value: any): boolean
	local ok = retry(function()
		store:SetAsync(key, value)
		return true
	end)
	return ok
end

-- Prefer UpdateAsync so concurrent servers merge instead of clobbering.
function DataStoreWrapper.update(store, key: string, transform: (any) -> any): boolean
	local ok = retry(function()
		store:UpdateAsync(key, function(old)
			return transform(old)
		end)
		return true
	end)
	return ok
end

return DataStoreWrapper
