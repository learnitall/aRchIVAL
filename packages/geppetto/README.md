# geppetto

> Puppet puppeteer from an interactive shell.

Geppetto is a small utility script for working with Puppeteer interactively on
a head-full browser.

It performs the following actions on startup:

1. Opens a non-headless browser and navigates to URL that was given on the
   command line.
2. Starts a session of Node's built in [REPL][noderepl].
3. Injects three variables into the REPL's global context: (1) the
   [Browser][browser] instance that was returned from [`puppeteer.launch`][launch],
   (2) the [Page][page] instance that was returned from [`Browser.newPage`][page],
   and (3) the imported puppeteer module itself.

This setup allows for quick iteration of snippets and selectors, which is
especially useful for those new to puppeteer and web development as a whole.
For example, we could write a selector, try it out, and invoke the
[`hover()`][hover] method on the result to see if the correct node was selected:

```console
> result = await page.$("input")
> await result.hover()
```

Or, we could test out a function passed to [`evaluate()`][eval] to see if it returns
the correct response. In this example, we learn that [`forEach`][forEach] does
not return:

```console
> await page.evaluate(() => {
... return document.querySelectorAll("a").forEach((el) => el.getAttribute("href"))
... })
undefined
> await page.evaluate(() => {
... const hrefs = [];
... document.querySelectorAll("a").forEach(el => {
...     hrefs.push(el.getAttribute("href"))
... })
... return hrefs;
})
[
    ...
]
```

## Building and running

There's an included `build` script in `package.json.` This creates a minified `.js`
file that can be executed with node:

```console
bun run build
node ./dist/geppetto.js
```

If [Nix][nixos] is available, the `nix` command can be used for building and running:

```console
nix build .#geppetto && ./result/bin/geppetto
nix run .#geppetto
```

If you're on NixOS and want to execute the file outputted by the build script
directly, you'll need to have node and chromium available:

```console
nix shell nixpkgs#nodejs nixpkgs#chromium
export PUPPETEER_EXECUTABLE_PATH=$(which chromium)
bun run build
node ./dist/geppetto.js
```

## A note on bun

Bun [does not implement the `node:repl` package][buncompat], therefore node is
required for geppetto to run. Bun's REPL, [https://github.com/jhmaster2000/bun-repl][bun-repl]
is experimental and unable to be used in this use case.

[noderepl]: https://nodejs.org/api/repl.html
[browser]: https://pptr.dev/api/puppeteer.browser
[launch]: https://pptr.dev/api/puppeteer.puppeteernode.launch
[page]: https://pptr.dev/api/puppeteer.page
[hover]: https://pptr.dev/api/puppeteer.page.hover
[eval]: https://pptr.dev/api/puppeteer.page.evaluate/
[forEach]: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/forEach
[nixos]: https://nixos.org/
[buncompat]: https://bun.sh/docs/runtime/nodejs-apis
[bun-repl]: https://github.com/jhmaster2000/bun-repl
