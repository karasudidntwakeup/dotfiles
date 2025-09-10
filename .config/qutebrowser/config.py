config.load_autoconfig(False)
# تفعيل ثيم Dracula
import dracula.draw

# لتحميل إعدادات :set السابقة تلقائيًا
config.load_autoconfig()

dracula.draw.blood(c, {
    'spacing': {
        'vertical': 6,
        'horizontal': 8
    }
})



# تفعيل مانع الإعلانات
config.set('content.blocking.enabled', True)

# تحميل قوائم حظر الإعلانات (EasyList + EasyPrivacy)
config.set('content.blocking.method', 'adblock')
config.set('content.blocking.adblock.lists', [
    'https://easylist.to/easylist/easylist.txt',
    'https://easylist.to/easylist/easyprivacy.txt',
    'https://secure.fanboy.co.nz/fanboy-cookiemonster.txt',
    'https://easylist-downloads.adblockplus.org/antiadblockfilters.txt',
])

c.colors.tabs.bar.bg = '#1e1e1e'
c.colors.tabs.odd.bg = '#2d2d2d'
c.colors.tabs.even.bg = '#2d2d2d'
c.colors.tabs.selected.odd.bg = '#44475a'
c.colors.tabs.selected.even.bg = '#44475a'


# تفعيل الوضع الداكن لمحتوى الصفحات
config.set("colors.webpage.preferred_color_scheme", "dark")
config.set("colors.webpage.darkmode.enabled", True)
config.set("colors.webpage.darkmode.policy.images", "smart")


c.statusbar.show = 'never'

c.fonts.statusbar = '10pt "Ndot 57"'
c.fonts.tabs.selected = '12pt "Ndot 57"'
c.fonts.tabs.unselected = '12pt "Ndot 57"'
