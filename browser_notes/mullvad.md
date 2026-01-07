Notes From Repo: https://github.com/dillacorn/win-glaze-dots

- ## install Mullvad browser
```sh
winget install MullvadVPN.MullvadBrowser
```

# config

navigate to: `about:config`

change these flags:
* middlemouse.paste: `false`
* privacy.fingerprintingProtection: `true`

# themes

**note**: *these are install links*

[`Dark space - The best dynamic theme by Nicothin`](https://addons.mozilla.org/firefox/downloads/file/4226329/nicothin_space-1.1.2.xpi)
[`Humble Gruvbox by Mekeor Melire`](https://addons.mozilla.org/firefox/downloads/file/2838072/humble_gruvbox-2.0.xpi)
[`Minimalist Gruvbox by canbeardig`](https://addons.mozilla.org/firefox/downloads/file/3991777/minimalist_gruvbox-2.0.xpi)
[`Minimalist Everforest by canbeardig`](https://addons.mozilla.org/firefox/downloads/file/4116967/minimalist_dark_and_yellow_tab-3.0.xpi)

# search engine

**search engines**: `(option #1)` - select a searx server (speed varies)

Name:
`Searx`

Find a searx server
`https://searx.space/`

**search engine**: `(option #2)` <- faster than searx

Name:
`brave`

URL with %s in place of query
`https://search.brave.com/search?q=%s`

# uBlock Origin
see [yokoffing](https://github.com/yokoffing) ["filterlists" Guidelines](https://github.com/yokoffing/filterlists?tab=readme-ov-file#recommended-filters-for-ublock-origin)

# custom dns server

navigate to `Privacy and security` in settings

enable `Max Protection`

add custom configured dns server from personal provider ~ I pay for nextdns ($2 a month)
### example dns server address

DNS-over-HTTPS: `https://dns.nextdns.io\xxxxxxx`

see [yokoffing](https://github.com/yokoffing) ["NextDNS-Config" Guidelines](https://github.com/yokoffing/NextDNS-Config?tab=readme-ov-file)

# Test Browser Security
https://browserleaks.com/webrtc

# personal settings

enable `Show home button` and add your preferred URL.. in my case "flame" and/or "hoarder" self hosted instance

disable `Show bookmarks bar`

vertical tabs:

![firefox_vertical_tabs_&_bar](https://raw.githubusercontent.com/dillacorn/arch-hypr-dots/main/browser_notes/firefox_vertical_tabs_&_bar.png)