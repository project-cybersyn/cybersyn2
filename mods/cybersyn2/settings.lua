data:extend({
	{
		type = "bool-setting",
		name = "cybersyn2-setting-enable-logistics",
		order = "aa",
		setting_type = "runtime-global",
		default_value = true,
	},
	{
		type = "bool-setting",
		name = "cybersyn2-setting-debug",
		order = "ab",
		setting_type = "runtime-global",
		-- TODO: set this to false for release
		default_value = true,
	},
	{
		type = "int-setting",
		name = "cybersyn2-setting-work-period",
		order = "ba",
		setting_type = "runtime-global",
		default_value = 2,
		minimum_value = 1,
		maximum_value = 60,
	},
	{
		type = "double-setting",
		name = "cybersyn2-setting-work-factor",
		order = "bb",
		setting_type = "runtime-global",
		default_value = 1.0,
		minimum_value = 0.01,
		maximum_value = 10.0,
	},
	{
		type = "int-setting",
		name = "cybersyn2-setting-network-mask",
		order = "bd",
		setting_type = "runtime-global",
		default_value = -1,
		minimum_value = -2147483648,
		maximum_value = 2147483647,
	},
	{
		type = "int-setting",
		name = "cybersyn2-setting-channel-mask",
		order = "bd",
		setting_type = "runtime-global",
		default_value = -1,
		minimum_value = -2147483648,
		maximum_value = 2147483647,
	},
	{
		type = "double-setting",
		name = "cybersyn2-setting-warmup-time",
		order = "ca",
		setting_type = "runtime-global",
		-- TODO: change default warmup time for release
		default_value = 1,
		minimum_value = 0,
		maximum_value = 2147483647,
	},
	{
		type = "int-setting",
		name = "cybersyn2-setting-queue-limit",
		order = "bc",
		setting_type = "runtime-global",
		default_value = 5,
		minimum_value = 0,
		maximum_value = 100,
	},
})
