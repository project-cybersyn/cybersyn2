script.on_init(raise_init)
script.on_configuration_changed(raise_configuration_changed)
script.on_event(defines.events.on_runtime_mod_setting_changed, handle_runtime_mod_setting_changed)
