# staticify

> Download a static version of a web page

Testing archival involves ensuring that a web page can be properly retrieved and
parsed, however we don't want to rely on external resources that may not always
be 100% available or may not appreciate continued requests. For example, the
Cilium project ran into flakes within its CI when tests would check connectivity
to external sites (see [cilium/cilium#23103][23103] and
[cilium/cilium-cli#1540][1540] for a couple of example fixes). To try and address
these kinds of flakes, we'll download a copy of the pages we want to ensure that
archival can parse correctly and host them locally. This doesn't replace tests
against external sites, which is still a necessary evil, but it will help speed
up development and debug any issues that may arise.

The staticify script is the first step in this process. It performs the following:

1. Opens up a puppeteer-controlled browser.
2. Navigates to the target url.
3. Waits for network requests to settle, allowing for the full page to be rendered.
   This is in contract to attempting to download the site with `curl`, as some sites
   may rely on javascript to fully display their content.
4. Finds all "a" elements that point to a relative link on the site and hard-codes
   the origin into them. For example, an "a" element that points to `/about` will
   instead point to `https://example.com/about`. This is important because these
   relative links are subjected to whatever domain the site is hosted on, and if
   we rehost the page those links will change.
5. Removes all script tags. After the content is rendered we don't need any
   javascript because we aren't interacting with the page. Removing the script tags
   enforces this policy and ensures no scripts need to be fetched from the origin.
6. Saves the resulting page to the given filepath.

## Building and running

There's an included `build` script in `package.json` which creates a compiled
compiled executable:

```console
bun run build
./dist/staticify
```

If [Nix][nixos] is available, the `nix` command can be used for building and running:

```console
nix build .#staticify && ./result/bin/staticify
nix run .#staticify
```

If you're on NixOS and want to execute the file outputted by the build script
directly, you'll need to have chromium available:

```console
nix shell nixpkgs#chromium
export PUPPETEER_EXECUTABLE_PATH=$(which chromium)
bun run build
./dist/staticify
```

[23103]: https://github.com/cilium/cilium/pull/23103
[1540]: https://github.com/cilium/cilium-cli/pull/1540
[nixos]: https://nixos.org/
