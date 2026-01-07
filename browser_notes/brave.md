notes from repo: https://github.com/dillacorn/win-glaze-dots

# I recommend brave. (manage updates with scoop)

- ## install brave
```sh
winget install Brave.Brave
```

# guide to make brave better
https://github.com/libalpm64/Better-Brave-Browser

# JavaScript optimization & security (recommended)

brave://settings/content/v8?search=java

![Chromium JavaScript optimization](https://raw.githubusercontent.com/dillacorn/arch-hypr-dots/main/browser_notes/chromium_javascript_optimization.png)

# flags

navigate to: `brave://flags/`

### ✅ Required Flags to Disable (without the #)

brave-cosmetic-filtering-sync-load  
brave-rewards-verbose-logging  
brave-rewards-allow-unsupported-wallet-providers  
brave-rewards-allow-self-custody-providers  
brave-rewards-new-rewards-ui  
brave-rewards-animated-background  
brave-rewards-platform-creator-detection  
brave-ads-allowed-to-fallback-to-custom-push-notification-ads  
native-brave-wallet  
brave-wallet-zcash  
brave-wallet-bitcoin  
brave-wallet-enable-ankr-balances  
brave-wallet-enable-transaction-simulations  
brave-news-peek  
brave-news-feed-update  
ethereum_remote-client_new-installs  
brave-rewards-gemini  
brave-ai-chat  
brave-ai-chat-history  
brave-ai-chat-context-menu-rewrite-in-place  
brave-ai-chat-page-content-refine  
brave-ai-chat-open-leo-from-brave-search  
brave-ai-chat-web-content-association-default  
brave-ai-rewriter

### ⚙️ Optional Flags (without the #)

fill-on-account-select → `Disabled`

enable-pending-mode-passwords-promo → `Disabled`

# Add filter list to built-in adblock
https://filterlists.com/

# extensions

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
[`Redirector`](https://chromewebstore.google.com/detail/redirector/ocgpenflpmgnfapjedencafcfakcekcd)

# `picture in picture` video tip 
- `Right-click` video `twice` and click `Picture in picture`

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

Place to manage your web apps: `brave://apps/`
