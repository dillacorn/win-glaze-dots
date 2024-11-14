Notes From Repo: https://github.com/dillacorn/win-glaze-dots

Librewolf is pretty great... 

# install
```sh
choco install librewolf -y
```

open "Librewolf"

# config

navigate to: `about:config`

change these flags:
* middlemouse.paste: `false`
* privacy.clearOnShutdown.cookies: `false`
* privacy.clearOnShutdown.downloads: `false`
* privacy.clearOnShutdown.history: `false`
* privacy.clearOnShutdown.offlineApps: `false`
* privacy.fingerprintingProtection: `true`
* widget.gtk.global-menu.wayland.enabled `true`

# extensions

**note**: *these are install links*

[`uBlock Origin`](https://addons.mozilla.org/firefox/downloads/file/4328681/ublock_origin-1.59.0.xpi)
[`LocalCDN`](https://addons.mozilla.org/firefox/downloads/file/4318983/localcdn_fork_of_decentraleyes-2.6.70.xpi)
[`ClearURLs`](https://addons.mozilla.org/firefox/downloads/file/4064884/clearurls-1.26.1.xpi)
[`Privacy Badger`](https://addons.mozilla.org/firefox/downloads/file/4321653/privacy_badger17-2024.7.17.xpi)
[`CanvasBlocker`](https://addons.mozilla.org/firefox/downloads/file/4262820/canvasblocker-1.10.1.xpi)
[`ScrollAnywhere`](https://addons.mozilla.org/firefox/downloads/file/3938344/scroll_anywhere-9.2.xpi)
[`Dark Reader`](https://addons.mozilla.org/firefox/downloads/file/4317971/darkreader-4.9.88.xpi)
[`Backspace Enabler`](https://addons.mozilla.org/firefox/downloads/file/3954457/backspace_enabler-1.0.xpi)
[`Key Jump keyboard navigation`](https://addons.mozilla.org/firefox/downloads/file/3887397/key_jump_keyboard_navigation-5.4.0.xpi)
[`Bitwarden Password Manager`](https://addons.mozilla.org/firefox/downloads/file/4326285/bitwarden_password_manager-2024.7.1.xpi)
[`To Google Translate`](https://addons.mozilla.org/firefox/downloads/file/3798719/to_google_translate-4.2.0.xpi)
[`Enhancer for YouTube`](https://addons.mozilla.org/firefox/downloads/file/4325319/enhancer_for_youtube-2.0.126.xpi)
[`Return YouTube Dislike`](https://addons.mozilla.org/firefox/downloads/file/4308076/return_youtube_dislikes-3.0.0.16.xpi)
[`SponsorBlock for YouTube`](https://addons.mozilla.org/firefox/downloads/file/4308094/sponsorblock-5.7.xpi)
[`Disable YouTube Seek by Number`](https://addons.mozilla.org/firefox/downloads/file/4308468/youtube_disable_number_seek-1.4.xpi)
[`Ctrl+Number to switch tabs`](https://addons.mozilla.org/firefox/downloads/file/4192880/ctrl_number_to_switch_tabs-1.0.2.xpi)
[`Tab Numbers`](https://addons.mozilla.org/firefox/downloads/file/3368371/tab_numbers-1.0.0.xpi)
[`User-Agent Switcher and Manager`](https://addons.mozilla.org/firefox/downloads/file/4098688/user_agent_string_switcher-0.5.0.xpi)
[`DeArrow - Better Titles and Thumbnails`](https://addons.mozilla.org/firefox/downloads/file/4307344/dearrow-1.6.4.xpi)
[`Search by Image`](https://addons.mozilla.org/firefox/downloads/file/4309046/search_by_image-7.1.0.xpi)
[`DownThemAll!`](https://addons.mozilla.org/firefox/downloads/file/4228862/downthemall-4.12.1.xpi)
[`FastForward`](https://addons.mozilla.org/firefox/downloads/file/4258067/fastforwardteam-0.2383.xpi)

# search engine

**search engine**: `(option #1)` - normally slower than startpage

Name:
`disroot`

URL with %s in place of query
`https://search.disroot.org/search?q=%s`

**search engine**: `(option #2)` <- usually faster than disroot

Name:
`brave`

URL with %s in place of query
`https://search.brave.com/search?q=%s`

# custom dns server

navigate to `Privacy and security` in settings

enable `Max Protection`

add custom configured dns server from personal provider ~ I pay for nextdns ($2 a month)
### example dns server address

DNS-over-HTTPS: `https://dns.nextdns.io\xxxxxxx`

# Test Browser Security
https://browserleaks.com/webrtc
