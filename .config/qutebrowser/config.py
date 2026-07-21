config.load_autoconfig(False)
config.set("qt.args", ["disable-gpu"])

try:
    config.source("colors.py")
except FileNotFoundError:
    pass
config.set('content.blocking.enabled', True)
config.set('content.blocking.method', 'adblock')
config.set('content.blocking.adblock.lists', [
    'https://easylist.to/easylist/easylist.txt',
    'https://easylist.to/easylist/easyprivacy.txt',
    'https://secure.fanboy.co.nz/fanboy-cookiemonster.txt',
    'https://easylist-downloads.adblockplus.org/antiadblockfilters.txt',
])



config.set("colors.webpage.preferred_color_scheme", "dark")
config.set("colors.webpage.darkmode.enabled", True)
config.set("colors.webpage.darkmode.policy.images", "smart")


c.statusbar.show = 'never'

c.fonts.statusbar = '7pt "Departure Mono"'
c.fonts.tabs.selected = '10pt "Departure Mono"'
c.fonts.tabs.unselected = '10pt "Departure Mono"'
