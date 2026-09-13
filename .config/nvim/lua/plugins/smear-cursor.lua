return {
  "sphamba/smear-cursor.nvim",
  event = "VeryLazy",
  opts = {
    -- Animation physics
    stiffness = 0.8,
    trailing_stiffness = 0.5,

    -- Hide target cursor during animation (prevents flickering in Foot)
    hide_target_cursor = true,

    -- Match cursor highlight group dynamically (or leave nil for defaults)
    cursor_color = nil,
  },
}
