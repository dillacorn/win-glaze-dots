notes from repo: https://github.com/dillacorn/win-glaze-dots

# choose a browser

- ## install cromite
```sh
sudo choco install cromite -y
```
### disable internal adblocker and install [uBlock Origin](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm)

- ## install ungoogled-chromium (prefered)
```sh
scoop install ungoogled-chromium -y
```

### add [chromium-web-store](https://github.com/NeverDecaf/chromium-web-store) to ungoogled-chromium (cromite does not required)

# flags

navigate to: `chrome://flags/`

change these flags:
* [enable-webrtc-allow-input-volume-adjustment](chrome://flags/#enable-webrtc-allow-input-volume-adjustment): `Disabled` <- Browser adjusting mic volume randomly is so annoying

# extensions

Privacy centric extensions:
[`uBlock Origin`](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm)
[`LocalCDN`](https://chromewebstore.google.com/detail/localcdn/njdfdhgcmkocbgbhcioffdbicglldapd)
[`ClearURLs`](https://chromewebstore.google.com/detail/clearurls/lckanjgmijmafbedllaakclkaicjfmnk)

Must have Extra extensions:
[`Chrome Show Tab Numbers`](https://chromewebstore.google.com/detail/chrome-show-tab-numbers/pflnpcinjbcfefgbejjfanemlgcfjbna)
[`SponsorBlock`](https://chromewebstore.google.com/detail/sponsorblock-for-youtube/mnjggcdmjocbbbhaepdhchncahnbgone)
[`Disable YouTube Number Keyboard Shortcuts`](https://chromewebstore.google.com/detail/disable-youtube-number-ke/lajiknjoinemadijnpdnjjdmpmpigmge)
[`Return YouTube Dislike`](https://chromewebstore.google.com/detail/return-youtube-dislike/gebbhagfogifgggkldgodflihgfeippi)
[`Bitwarden Password Manager`](https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb)
[`ScrollAnywhere`](https://chromewebstore.google.com/detail/scrollanywhere/jehmdpemhgfgjblpkilmeoafmkhbckhi)

Extra extensions I can live without:
[`Dark Reader`](https://chromewebstore.google.com/detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh)
[`Key Jump keyboard navigation`](https://chromewebstore.google.com/detail/key-jump-keyboard-navigat/afdjhbmagopjlalgcjfclkgobaafamck)
[`Go Back With Backspace`](https://chromewebstore.google.com/detail/go-back-with-backspace/eekailopagacbcdloonjhbiecobagjci)
[`Simple Translate`](https://chromewebstore.google.com/detail/simple-translate/ibplnjkanclpjokhdolnendpplpjiace)
[`DeArrow - Better Titles and Thumbnails`](https://chromewebstore.google.com/detail/dearrow-better-titles-and/enamippconapkdmgfgjchkhakpfinmaj)
[`Search by Image`](https://chromewebstore.google.com/detail/search-by-image/cnojnbdhbhnkbcieeekonklommdnndci)
[`DownThemAll!`](https://chromewebstore.google.com/detail/downthemall/nljkibfhlpcnanjgbnlnbjecgicbjkge)

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

**search engine**: `(option #2)` <- usually faster than searx

Name:
`Brave`

URL with %s in place of query
`https://search.brave.com/search?q=%s`

# custom dns server

navigate to `Privacy and security` in settings ~ brave://settings/security

enable `Use secure DNS`

add custom configured dns server from personal provider ~ I pay for nextdns ($2 a month)
### example dns server address

DNS-over-HTTPS: `https://dns.nextdns.io\xxxxxxx`

# test browser security
https://browserleaks.com/webrtc

# personal settings

enable `Show home button` and add your preferred URL.. in my case "flame" and/or "hoarder" self hosted instance

disable `Show bookmarks bar`
