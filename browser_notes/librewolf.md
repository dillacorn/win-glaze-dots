Notes From Repo: https://github.com/dillacorn/win-glaze-dots

Librewolf is easy firefox hardened utilizing arkenfox user.js

# install
```sh
choco install librewolf -y
```

open "Librewolf"

# config

navigate to: `about:config`

change these flags:
* middlemouse.paste: `false`
* privacy.fingerprintingProtection: `true`

# extensions

**note**: *these are install links*

Security Centric:
[`uBlock Origin`](https://addons.mozilla.org/firefox/downloads/file/4328681/ublock_origin-1.59.0.xpi)
[`LocalCDN`](https://addons.mozilla.org/firefox/downloads/file/4318983/localcdn_fork_of_decentraleyes-2.6.70.xpi)
[`ClearURLs`](https://addons.mozilla.org/firefox/downloads/file/4064884/clearurls-1.26.1.xpi)
[`CanvasBlocker`](https://addons.mozilla.org/firefox/downloads/file/4262820/canvasblocker-1.10.1.xpi)

Extras:
[`ScrollAnywhere`](https://addons.mozilla.org/firefox/downloads/file/3938344/scroll_anywhere-9.2.xpi)
[`Dark Reader`](https://addons.mozilla.org/firefox/downloads/file/4317971/darkreader-4.9.88.xpi)
[`Backspace Enabler`](https://addons.mozilla.org/firefox/downloads/file/3954457/backspace_enabler-1.0.xpi)
[`Key Jump keyboard navigation`](https://addons.mozilla.org/firefox/downloads/file/3887397/key_jump_keyboard_navigation-5.4.0.xpi)
[`To Google Translate`](https://addons.mozilla.org/firefox/downloads/file/3798719/to_google_translate-4.2.0.xpi)
[`Ctrl+Number to switch tabs`](https://addons.mozilla.org/firefox/downloads/file/4192880/ctrl_number_to_switch_tabs-1.0.2.xpi)
[`Tab Numbers`](https://addons.mozilla.org/firefox/downloads/file/3368371/tab_numbers-1.0.0.xpi)
[`FastForward`](https://addons.mozilla.org/firefox/downloads/file/4258067/fastforwardteam-0.2383.xpi)

# themes

**note**: *these are install links*

[`Dark space - The best dynamic theme by Nicothin`](https://addons.mozilla.org/firefox/downloads/file/4226329/nicothin_space-1.1.2.xpi)
[`Humble Gruvbox by Mekeor Melire`](https://addons.mozilla.org/firefox/downloads/file/2838072/humble_gruvbox-2.0.xpi)
[`Minimalist Gruvbox by canbeardig`](https://addons.mozilla.org/firefox/downloads/file/3991777/minimalist_gruvbox-2.0.xpi)
[`Minimalist Everforest by canbeardig`](https://addons.mozilla.org/firefox/downloads/file/4116967/minimalist_dark_and_yellow_tab-3.0.xpi)

# search engine

**search engine**: `(option #1)` - slower than brave

Name:
`disroot`

URL with %s in place of query
`https://search.disroot.org/search?q=%s`

**search engine**: `(option #2)` <- faster than disroot

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
