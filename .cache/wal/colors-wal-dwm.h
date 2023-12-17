static const char norm_fg[] = "#f1f1f1";
static const char norm_bg[] = "#191919";
static const char norm_border[] = "#a8a8a8";

static const char sel_fg[] = "#f1f1f1";
static const char sel_bg[] = "#191919";
static const char sel_border[] = "#f1f1f1";

static const char urg_fg[] = "#f1f1f1";
static const char urg_bg[] = "#707070";
static const char urg_border[] = "#707070";

static const char *colors[][3]      = {
    /*               fg           bg         border                         */
    [SchemeNorm] = { norm_fg,     norm_bg,   norm_border }, // unfocused wins
    [SchemeSel]  = { sel_fg,      sel_bg,    sel_border },  // the focused win
    [SchemeUrg] =  { urg_fg,      urg_bg,    urg_border },
};
