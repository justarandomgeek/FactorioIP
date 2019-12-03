data:extend{
  {
    type = "int-setting",
    name = "routablecombinators-rx-buffer-size",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 1,
    order="routablecombinators-10-rx-buffer-size",
  },
  {
    type = "int-setting",
    name = "routablecombinators-rx-frame-size",
    setting_type = "startup",
    default_value = 500,
    minimum_value = 260,
    order="routablecombinators-11-rx-frame-size",
  },
  {
    type = "int-setting",
    name = "routablecombinators-tx-buffer-size",
    setting_type = "runtime-global",
    default_value = 60,
    minimum_value = 1,
    order="routablecombinators-20-tx-buffer-size",
  },
  {
    type = "bool-setting",
    name = "routablecombinators-enable-padding",
    setting_type = "startup",
    default_value = false,
    order="routablecombinators-30-enable-padding",
  },
  {
    type = "int-setting",
    name = "routablecombinators-start-padding",
    setting_type = "startup",
    default_value = 254,
    minimum_value = 1,
    order="routablecombinators-31-start-padding",
  },
  {
    type = "int-setting",
    name = "routablecombinators-stop-padding",
    setting_type = "startup",
    default_value = 319,
    minimum_value = 2,
    order="routablecombinators-32-stop-padding",
  },
}