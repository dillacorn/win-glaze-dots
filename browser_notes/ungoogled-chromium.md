notes from repo: https://github.com/dillacorn/win-glaze-dots

# I recommend ungoogled-chromium. (manage updates with scoop)

- ## install ungoogled-chromium
```sh
scoop install extras/ungoogled-chromium
```

- ## to update (specifically) ungoogled-chromium with scoop
```sh
scoop update extras/ungoogled-chromium
```

- ## to update all applications installed with scoop
```sh
scoop update *
```

### add [chromium-web-store](https://github.com/NeverDecaf/chromium-web-store) to ungoogled-chromium

# flags

navigate to: `chrome://flags/`

change these flags:
* [extension-mime-request-handling](chrome://flags/#extension-mime-request-handling): `Always prompt for install` <- Fix for easy extension install
* [enable-webrtc-allow-input-volume-adjustment](chrome://flags/#enable-webrtc-allow-input-volume-adjustment): `Disabled` <- Browser adjusting mic volume randomly is so annoying
* [Disable search engine collection](chrome://flags/#disable-search-engine-collection): `Enabled`
* [Enable get*ClientRects() fingerprint deception](chrome://flags/#fingerprinting-client-rects-noise): `Enabled`
* [Enable Canvas::measureText() fingerprint deception](chrome://flags/#fingerprinting-canvas-measuretext-noise): `Enabled`
* [Enable Canvas image data fingerprint deception](chrome://flags/#fingerprinting-canvas-image-data-noise): `Enabled`
* [Anonymize local IPs exposed by WebRTC](chrome://flags/#enable-webrtc-hide-local-ips-with-mdns): `Enabled`

# extensions

Privacy centric extensions:
[`uBlock Origin`](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm)
[`LocalCDN`](https://chromewebstore.google.com/detail/localcdn/njdfdhgcmkocbgbhcioffdbicglldapd)
[`ClearURLs`](https://chromewebstore.google.com/detail/clearurls/lckanjgmijmafbedllaakclkaicjfmnk)
##### Quick install with [chromium-web-store](https://github.com/NeverDecaf/chromium-web-store) ~ copy pasta
```
uBlock Origin|cjpalhdlnbpafiamejdnhcphjbkeiagm
ClearURLs|lckanjgmijmafbedllaakclkaicjfmnk
LocalCDN|njdfdhgcmkocbgbhcioffdbicglldapd
```

---
Must have Extra extensions:
[`Chrome Show Tab Numbers`](https://chromewebstore.google.com/detail/chrome-show-tab-numbers/pflnpcinjbcfefgbejjfanemlgcfjbna)
[`SponsorBlock`](https://chromewebstore.google.com/detail/sponsorblock-for-youtube/mnjggcdmjocbbbhaepdhchncahnbgone)
[`Disable YouTube Number Keyboard Shortcuts`](https://chromewebstore.google.com/detail/disable-youtube-number-ke/lajiknjoinemadijnpdnjjdmpmpigmge)
[`Return YouTube Dislike`](https://chromewebstore.google.com/detail/return-youtube-dislike/gebbhagfogifgggkldgodflihgfeippi)
[`Bitwarden Password Manager`](https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb)
[`ScrollAnywhere`](https://chromewebstore.google.com/detail/scrollanywhere/jehmdpemhgfgjblpkilmeoafmkhbckhi)
##### Quick install with [chromium-web-store](https://github.com/NeverDecaf/chromium-web-store) ~ copy pasta
```
Return YouTube Dislike|gebbhagfogifgggkldgodflihgfeippi
ScrollAnywhere|jehmdpemhgfgjblpkilmeoafmkhbckhi
Disable YouTube Number Keyboard Shortcuts|lajiknjoinemadijnpdnjjdmpmpigmge
SponsorBlock for YouTube - Skip Sponsorships|mnjggcdmjocbbbhaepdhchncahnbgone
Bitwarden Password Manager|nngceckbapebfimnlniiiahkandclblb
Chrome Show Tab Numbers|pflnpcinjbcfefgbejjfanemlgcfjbna
```

Extra extensions I can live without:
[`Dark Reader`](https://chromewebstore.google.com/detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh)
[`Key Jump keyboard navigation`](https://chromewebstore.google.com/detail/key-jump-keyboard-navigat/afdjhbmagopjlalgcjfclkgobaafamck)
[`Go Back With Backspace`](https://chromewebstore.google.com/detail/go-back-with-backspace/eekailopagacbcdloonjhbiecobagjci)
[`Simple Translate`](https://chromewebstore.google.com/detail/simple-translate/ibplnjkanclpjokhdolnendpplpjiace)
[`DeArrow - Better Titles and Thumbnails`](https://chromewebstore.google.com/detail/dearrow-better-titles-and/enamippconapkdmgfgjchkhakpfinmaj)
[`Search by Image`](https://chromewebstore.google.com/detail/search-by-image/cnojnbdhbhnkbcieeekonklommdnndci)
[`DownThemAll!`](https://chromewebstore.google.com/detail/downthemall/nljkibfhlpcnanjgbnlnbjecgicbjkge)
[`Redirector`](https://chromewebstore.google.com/detail/redirector/ocgpenflpmgnfapjedencafcfakcekcd)
##### Quick install with [chromium-web-store](https://github.com/NeverDecaf/chromium-web-store) ~ copy pasta
```
Key Jump keyboard navigation|afdjhbmagopjlalgcjfclkgobaafamck
Search by Image|cnojnbdhbhnkbcieeekonklommdnndci
Go Back With Backspace|eekailopagacbcdloonjhbiecobagjci
Dark Reader|eimadpbcbfnmbkopoojfekhnkhdbieeh
DeArrow - Better Titles and Thumbnails|enamippconapkdmgfgjchkhakpfinmaj
Simple Translate|ibplnjkanclpjokhdolnendpplpjiace
DownThemAll!|nljkibfhlpcnanjgbnlnbjecgicbjkge
Redirector|ocgpenflpmgnfapjedencafcfakcekcd
```

# theme

[`Dark-10`](https://chromewebstore.google.com/detail/dark-10/baebencgofnhbdimnijacljeoegbokeh)
[`Material Simple Dark Grey`](https://chromewebstore.google.com/detail/material-simple-dark-grey/ookepigabmicjpgfnmncjiplegcacdbm)

# `picture in picture` video tip 
- `Right-click` video `twice` and click `Picture in picture`

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

# custom dns server

navigate to `Privacy and security` in settings

enable `Use secure DNS`

add custom configured dns server from personal provider ~ I pay for nextdns ($2 a month)
### example dns server address

DNS-over-HTTPS: `https://dns.nextdns.io\xxxxxxx`

see [yokoffing](https://github.com/yokoffing) ["NextDNS-Config" Guidelines](https://github.com/yokoffing/NextDNS-Config?tab=readme-ov-file)

# test browser security
https://browserleaks.com/webrtc

# personal settings

enable `Show home button` and add your preferred URL.. in my case "flame" and/or "hoarder" self hosted instance

disable `Show bookmarks bar`

# web apps

Place to manage your web apps: `chrome://apps/`