# dotfiles-mobile

> Flutter/Android/iOS/React Native shell aliases (dot_config/zsh/dev.zsh).
> FVM, cocoapods and fastlane are opt-in now -- `brewopt mobile` first.
> More information: <https://github.com/aghnyap/dotfiles>.

- FVM-pinned Flutter, any subcommand:

`fl {{run|clean|...}}`

- FVM-pinned Dart, any subcommand:

`fld {{command}}`

- Flutter pub get:

`flpg`

- Flutter pub upgrade:

`flpu`

- Flutter test:

`flt`

- Flutter analyze:

`fla`

- Flutter build_runner build:

`flgen`

- melos, any subcommand, across a monorepo:

`ml {{command}}`

- melos bootstrap:

`mlb`

- melos clean:

`mlc`

- Gradle wrapper: clean:

`gwc`

- Gradle wrapper: build:

`gwb`

- Gradle wrapper: bootRun:

`gwr`

- Gradle wrapper: test:

`gwtest`

- Gradle wrapper: all tasks:

`gwtasks`

- Gradle wrapper: assembleDebug:

`gwad`

- Gradle wrapper: kill daemons:

`gwstop`

- Gradle wrapper: bootRun with the JVM debugger on :5005:

`gwdebug`

- adb: pick a device:

`adbd`

- adb: tail logcat, colorized, for one package:

`logcat {{package}}`

- adb: install an APK:

`apkinstall`

- adb: restart the daemon:

`adbr`

- Mirror a device's screen (scrcpy):

`mirror`

- Record a device's screen (scrcpy):

`screenrec`

- Decode an APK's badging info via aapt2:

`apk-info {{app.apk}}`

- Switch the active JDK for this shell session:

`jdk {{version}}`

- Containers, needs `brewopt backend`: pretty `docker ps`:

`dps`

- Containers: compose up -d:

`dcu`

- Containers: compose down:

`dcd`

- Containers: compose logs -f:

`dcl`

- iOS Simulator: list devices:

`simlist`

- iOS Simulator: boot a device:

`simboot`

- iOS Simulator: shut down:

`simshutdown`

- CocoaPods install:

`pods`

- CocoaPods full clean and reinstall:

`podsclean`

- Xcode DerivedData clean:

`xcclean`

- npm install (short alias, not React Native-specific):

`ni`

- npm run \<script\> (short alias):

`nr {{script}}`

- npm run dev (short alias):

`nrd`

- React Native: start Metro:

`metro`

- React Native: run on iOS:

`rnios`

- React Native: run on Android:

`rnandroid`

- React Native: full cache reset (Metro + haste):

`rnreset`
