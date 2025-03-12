Notes From Repo: https://github.com/dillacorn/win-glaze-dots

# choose a browser

- ## install librewolf
```sh
scoop install extras/librewolf
```

- ## install mullvad-browser (prefered)
```sh
scoop install extras/mullvad-browser
```

# config

navigate to: `about:config`

change these flags:
* middlemouse.paste: `false`
* privacy.fingerprintingProtection: `true`

# extensions

**note**: *these are install links*

Security Centric (must have):
[`uBlock Origin`](https://addons.mozilla.org/firefox/downloads/file/4328681/ublock_origin-1.59.0.xpi)
[`LocalCDN`](https://addons.mozilla.org/firefox/downloads/file/4318983/localcdn_fork_of_decentraleyes-2.6.70.xpi)
[`ClearURLs`](https://addons.mozilla.org/firefox/downloads/file/4064884/clearurls-1.26.1.xpi)
[`CanvasBlocker`](https://addons.mozilla.org/firefox/downloads/file/4262820/canvasblocker-1.10.1.xpi)

Plugins I personally can't live without:
[`ScrollAnywhere`](https://addons.mozilla.org/firefox/downloads/file/3938344/scroll_anywhere-9.2.xpi)
[`Bitwarden Password Manager`](https://addons.mozilla.org/firefox/downloads/file/4326285/bitwarden_password_manager-2024.7.1.xpi)
[`SponsorBlock for YouTube`](https://addons.mozilla.org/firefox/downloads/file/4308094/sponsorblock-5.7.xpi)
[`Ctrl+Number to switch tabs`](https://addons.mozilla.org/firefox/downloads/file/4192880/ctrl_number_to_switch_tabs-1.0.2.xpi)
[`Disable YouTube Seek by Number`](https://addons.mozilla.org/firefox/downloads/file/4308468/youtube_disable_number_seek-1.4.xpi)
[`Return YouTube Dislike`](https://addons.mozilla.org/firefox/downloads/file/4308076/return_youtube_dislikes-3.0.0.16.xpi)
[`Tab Numbers`](https://addons.mozilla.org/firefox/downloads/file/3368371/tab_numbers-1.0.0.xpi)

Some Additional Plugins:
[`Undo Close Tab`](https://addons.mozilla.org/firefox/downloads/file/4212173/undoclosetabbutton-8.0.0.xpi)
[`Move Tabs`](https://addons.mozilla.org/firefox/downloads/file/4272424/move_tabs_around-0.0.3resigned1.xpi)
[`FastForward`](https://addons.mozilla.org/firefox/downloads/file/4258067/fastforwardteam-0.2383.xpi)
[`Dark Reader`](https://addons.mozilla.org/firefox/downloads/file/4317971/darkreader-4.9.88.xpi)
[`Backspace Enabler`](https://addons.mozilla.org/firefox/downloads/file/3954457/backspace_enabler-1.0.xpi)
[`Key Jump keyboard navigation`](https://addons.mozilla.org/firefox/downloads/file/3887397/key_jump_keyboard_navigation-5.4.0.xpi)
[`To Google Translate`](https://addons.mozilla.org/firefox/downloads/file/3798719/to_google_translate-4.2.0.xpi)
[`Enhancer for YouTube`](https://addons.mozilla.org/firefox/downloads/file/4325319/enhancer_for_youtube-2.0.126.xpi)
[`User-Agent Switcher and Manager`](https://addons.mozilla.org/firefox/downloads/file/4098688/user_agent_string_switcher-0.5.0.xpi)
[`DeArrow - Better Titles and Thumbnails`](https://addons.mozilla.org/firefox/downloads/file/4307344/dearrow-1.6.4.xpi)
[`Search by Image`](https://addons.mozilla.org/firefox/downloads/file/4309046/search_by_image-7.1.0.xpi)
[`DownThemAll!`](https://addons.mozilla.org/firefox/downloads/file/4228862/downthemall-4.12.1.xpi)

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

**search engine**: `(option #2)` <- usually faster than searx

Name:
`Brave`

URL with %s in place of query
`https://search.brave.com/search?q=%s`

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
