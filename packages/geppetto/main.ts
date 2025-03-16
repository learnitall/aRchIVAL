#!/usr/bin/env node
/**
 * SPDX-License-Identifier: AGPL-3.0-or-later
 *
 * Copyright 2025, the aRchIVAL contributors.
 *
 * This file is part of aRchIVAL.
 *
 * aRchIVAL is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
 * Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any
 * later version.
 *
 * aRchIVAL is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
 * warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License along with aRchIVAL. If not,
 * see <https://www.gnu.org/licenses/>.
 */
import repl from "node:repl";
import puppeteer from "puppeteer";

async function openPage(url: string) {
	console.log("Launching browser");
	const browser = await puppeteer.launch({ headless: false });
	const page = await browser.newPage();
	await page.setUserAgent(
		"Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36",
	);

	console.log(`Navigating to ${url}`);
	await page.goto(url);
	await page.waitForNetworkIdle();
	const local = repl.start({ useGlobal: true });

	local.context.browser = browser;
	local.context.page = page;
	local.context.puppeteer = puppeteer;
	local.on("exit", () => {
		console.log("Exiting");
		browser.close();
	});
}

(async () => {
	let url = process.argv.at(2);
	if (url === undefined) {
		url = "https://www.google.com";
	}
	await openPage(url);
})();
