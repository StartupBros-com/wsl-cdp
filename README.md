**wsl-cdp now lives at [`plugins/wsl-cdp/` in StartupBros-com/hov-stack](https://github.com/StartupBros-com/hov-stack/tree/main/plugins/wsl-cdp).**

This repository is archived. It keeps the history and releases up to v0.3.6.
Releases from v0.3.7 on, issues and pull requests are in
[StartupBros-com/hov-stack](https://github.com/StartupBros-com/hov-stack). Its open issues moved there with the `plugin:wsl-cdp` label.

## Install

From the [House of Vibe marketplace](https://github.com/StartupBros-com/hov-stack):

```
/plugin marketplace add StartupBros-com/hov-stack
/plugin install wsl-cdp@hov
```

An existing install from the marketplace picks up the new home on its next
plugin update. There is nothing to reinstall.

## Command-line install

The one-line installer moved with it:

```bash
curl -fsSL "https://raw.githubusercontent.com/StartupBros-com/hov-stack/main/plugins/wsl-cdp/install.sh?$(date +%s)" | bash
```

The installer URL in this repository still answers, but it installs this
archived copy, which gets no further fixes.
