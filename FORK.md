# Why this fork exists

Upstream Termux:X11 opens every `-tag` window as the same activity, so on a Samsung Galaxy
Z Fold 7 running One UI every Linux app shows up as **Termux:X11** with the Termux:X11 icon,
in the window caption, in Recents, in the DeX taskbar and in the DeX app overview. This fork
gives each app its own name and icon.

It is used by the `lx` dispatcher in the companion `lx-launcher` project, which runs the apps
in an Arch chroot and starts one X server per app.

## What changed

**Per-app activities.** `tools/lx-gen-aliases.sh` generates one `TaggedApp_<id>` activity per
Linux app: a subclass of `MainActivity.MainActivityTagged` plus a manifest entry carrying that
app's `android:label`, `android:icon` and `android:taskAffinity`.
`MainActivity.startTaggedActivity()` routes a tag to its generated activity when one exists and
falls back to the plain tagged activity when it does not, so an app that has not been generated
yet still opens normally.

**A task description as a fallback.** `MainActivity.applyTaskDescription()` calls
`setTaskDescription()` with a name from the launch intent's `EXTRA_TITLE`, or from
`files/lx-tags/<tag>.name`, and an icon from `files/lx-tags/<tag>.png`. Those files are written
by `lx` whenever it launches an app. One UI ignores this, but it is what labels a window on
other launchers and it costs nothing.

## What One UI still does not honour

The DeX taskbar groups every window of one package into a single entry and labels the whole
group from one member. With Zen Browser and Terminal both open, the taskbar shows one icon and
its window list calls both windows "Zen Browser". A per-app `taskAffinity` does not split the
group; only separate packages would. Window captions, the DeX app overview and Recents are all
correct.

## Adding an app

1. Add the app to `/etc/lx/apps.conf` in the chroot and launch it once, so `lx` publishes its
   name and icon under `/data/data/com.termux.x11/files/lx-tags`.
2. Run `tools/lx-rebuild.sh`. It pulls that directory into `lorie/lx-apps`, regenerates the
   activities and drawables, builds and installs.
3. Relaunch the app so its window is created by the new activity.

`lorie/lx-apps` is the checked-in spec: `<id>.name` holds the label, `<id>.png` the icon.

## Building on macOS

Two things bite on a stock macOS checkout.

**The filesystem must be case-sensitive.** On case-insensitive APFS the compiler resolves
`<xlocale.h>` to X11's `Xlocale.h` and the build dies with `unknown type name 'locale_t'`.
Build from a case-sensitive volume:

```sh
hdiutil create -size 12g -fs "Case-sensitive APFS" -volname tx11build -type SPARSE tx11build
hdiutil attach tx11build.sparseimage
```

**The vendored patches do not get applied.** The build applies each submodule patch only if a
reverse dry-run fails first, and BSD `patch -R --dry-run` reports success where GNU `patch`
reports failure, so every patch is silently skipped and the build fails later with missing
symbols such as `after_flip` and `xkbcomp_main`. Apply them once by hand, exactly once per
submodule, and check the markers landed. If a patch gets applied twice you will see
`redefinition of 'lorieRecheckGpuCopies'`; recover with `git checkout -- . && git clean -fdq`
inside each submodule and start over.

Then:

```sh
JAVA_HOME=/opt/homebrew/opt/openjdk@17 ./gradlew :lorie-app:assembleStandaloneDebug
```

The native build is the slow part and is cached, so a change to the manifest, the generated
activities or the Java sources rebuilds in a few seconds.
