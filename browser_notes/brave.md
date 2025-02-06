notes from repo: https://github.com/dillacorn/win-glaze-dots

For when FireFox isn't capable of the task.. or for compatibility reasons..

# start here
```sh
choco install brave -y
```

- open "brave" with flow-launcher `alt+p`

# flags

navigate to: `chrome://flags/`

change these flags:
* [enable-webrtc-allow-input-volume-adjustment](chrome://flags/#enable-webrtc-allow-input-volume-adjustment): `Disabled` <- Browser adjusting mic volume randomly is so annoying

# extensions

Privacy Centric:
[`uBlock Origin`](https://chromewebstore.google.com/detail/ublock-origin/cjpalhdlnbpafiamejdnhcphjbkeiagm)
[`LocalCDN`](https://chromewebstore.google.com/detail/localcdn/njdfdhgcmkocbgbhcioffdbicglldapd)
[`ClearURLs`](https://chromewebstore.google.com/detail/clearurls/lckanjgmijmafbedllaakclkaicjfmnk)

Extras:
[`Chrome Show Tab Numbers`](https://chromewebstore.google.com/detail/chrome-show-tab-numbers/pflnpcinjbcfefgbejjfanemlgcfjbna)
[`ScrollAnywhere`](https://chromewebstore.google.com/detail/scrollanywhere/jehmdpemhgfgjblpkilmeoafmkhbckhi)
[`Dark Reader`](https://chromewebstore.google.com/detail/dark-reader/eimadpbcbfnmbkopoojfekhnkhdbieeh)
[`Key Jump keyboard navigation`](https://chromewebstore.google.com/detail/key-jump-keyboard-navigat/afdjhbmagopjlalgcjfclkgobaafamck)
[`Go Back With Backspace`](https://chromewebstore.google.com/detail/go-back-with-backspace/eekailopagacbcdloonjhbiecobagjci)
[`Bitwarden Password Manager`](https://chromewebstore.google.com/detail/bitwarden-password-manage/nngceckbapebfimnlniiiahkandclblb)
[`Simple Translate`](https://chromewebstore.google.com/detail/simple-translate/ibplnjkanclpjokhdolnendpplpjiace)
[`Return YouTube Dislike`](https://chromewebstore.google.com/detail/return-youtube-dislike/gebbhagfogifgggkldgodflihgfeippi)
[`DeArrow - Better Titles and Thumbnails`](https://chromewebstore.google.com/detail/dearrow-better-titles-and/enamippconapkdmgfgjchkhakpfinmaj)
[`Search by Image`](https://chromewebstore.google.com/detail/search-by-image/cnojnbdhbhnkbcieeekonklommdnndci)
[`DownThemAll!`](https://chromewebstore.google.com/detail/downthemall/nljkibfhlpcnanjgbnlnbjecgicbjkge)
[`FastForward`](https://chromewebstore.google.com/detail/fastforward/icallnadddjmdinamnolclfjanhfoafe)
[`SponsorBlock`](https://chromewebstore.google.com/detail/sponsorblock-for-youtube/mnjggcdmjocbbbhaepdhchncahnbgone)
[`Disable YouTube Number Keyboard Shortcuts`](https://chromewebstore.google.com/detail/disable-youtube-number-ke/lajiknjoinemadijnpdnjjdmpmpigmge)

# theme

[`Dark-10`](https://chromewebstore.google.com/detail/dark-10/baebencgofnhbdimnijacljeoegbokeh)

# `picture in picture` video tip 
- `Right-click` video `twice` and click `Picture in picture`

# search engine

**search engine**: `(option #1)` - normally slower than brave

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

navigate to `Privacy and security` in settings ~ brave://settings/security

enable `Use secure DNS`

add custom configured dns server from personal provider ~ I pay for nextdns ($2 a month)
### example dns server address

DNS-over-HTTPS: `https://dns.nextdns.io\xxxxxxx`

# test browser security
https://browserleaks.com/webrtc

# personal settings

navigate to `appearance`

choose mode `Dark`

enable `Show home button` and add my personal `flame` domain running on my personal OpenMediaVault NAS.

disable `Show bookmarks bar`
