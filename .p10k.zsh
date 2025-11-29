# ───────── Layout ─────────
typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs)
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=()

# ───────── Rose‑Pine Colors ─────────
typeset -g POWERLEVEL9K_DIR_FOREGROUND=171         # dusty rose
typeset -g POWERLEVEL9K_HOME_FOREGROUND=79         # teal / sage
typeset -g POWERLEVEL9K_VCS_BRANCH_FOREGROUND=80   # pine-green
typeset -g POWERLEVEL9K_VCS_CLEAN_FOREGROUND=84    # sea-foam
typeset -g POWERLEVEL9K_VCS_MODIFIED_FOREGROUND=180 # amber
typeset -g POWERLEVEL9K_PROMPT_CHAR_FOREGROUND=171 # dusty rose

# ───────── Transparent / Translucent Background ─────────
typeset -g POWERLEVEL9K_BACKGROUND=''  # remove background, let terminal show through

# ───────── Icons (Nerd Font) ─────────
typeset -g POWERLEVEL9K_DIR_VISUAL_IDENTIFIER_EXPANSION=' '  # folder
typeset -g POWERLEVEL9K_VCS_VISUAL_IDENTIFIER_EXPANSION=''  # git

# ───────── Minimal Style ─────────
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
typeset -g POWERLEVEL9K_LEFT_SUBSEGMENT_SEPARATOR=''
typeset -g POWERLEVEL9K_RIGHT_SUBSEGMENT_SEPARATOR=''
typeset -g POWERLEVEL9K_LEFT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
typeset -g POWERLEVEL9K_RIGHT_PROMPT_FIRST_SEGMENT_START_SYMBOL=''
typeset -g POWERLEVEL9K_RIGHT_PROMPT_LAST_SEGMENT_END_SYMBOL=''
typeset -g POWERLEVEL9K_VISUAL_IDENTIFIER_EXPANSION='%F{}${P9K_VISUAL_IDENTIFIER}%f'

