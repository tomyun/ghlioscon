# Ghlioscon
**G**uitar **H**ero **L**ive **iOS con**troller for macOS

## Requirements
- Bluetooth Guitar Hero Live controller (for iPhone/iPad/Apple TV)
- macOS (tested on 10.14.5)

## Installation
1. Install [foohid](https://github.com/unbit/foohid) driver
   - Probably need to build one yourself as installer package is no longer provided
   - [Disable SIP](https://developer.apple.com/library/archive/documentation/Security/Conceptual/System_Integrity_Protection_Guide/ConfiguringSystemIntegrityProtection/ConfiguringSystemIntegrityProtection.html) (`csrutil disable` on Recovery OS)
   - `.kext` must be signed by developer certificate ([free membership](https://developer.apple.com/support/compare-memberships/) okay)
   - Copy `foohid.kext` into `/Library/Extensions`
   - Set proper ownership (`sudo chown -R root:wheel foohid.kext`)
   - Reboot
2. Download [ghlioscon.swift](https://raw.githubusercontent.com/tomyun/ghlioscon/master/ghlioscon.swift)

## Usage
1. Make sure Bluetooth turned on with your Mac
2. Run `swift ghlioscon.swift` on terminal
3. Turn on your guitar controller by pressing Power button
4. Play

## Screenshots
### Clone Hero
Only works with [0.21.6](https://clonehero.net/releases/v0.21.6/) for now
![Clone Hero](https://i.imgur.com/ljdyeNg.png)

### Guitar Freaks (MAME)
![Guitar Freaks](https://i.imgur.com/19z8gKg.png)
