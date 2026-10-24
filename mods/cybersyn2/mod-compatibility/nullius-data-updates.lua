if not mods["nullius"] then return end

-- Nullius resets groups/subgroups in its data-updates phase, so we update ours to match.
data.raw["recipe"]["cybersyn2-combinator"].subgroup = data.raw["train-stop"]["train-stop"].subgroup
data.raw["item"]["cybersyn2-combinator"].subgroup = data.raw["item"]["train-stop"].subgroup
