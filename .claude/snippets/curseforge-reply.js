// Manners -- answer one CurseForge comment, once.
//
// Not shipped (.claude is not packaged). Paste into the page through Claude in
// Chrome's javascript_tool on https://www.curseforge.com/wow/addons/manners/comments
// (signed in as fpsacha), then call:
//
//   await window.mannersReply("<author as the page shows it>", "<a few words of their comment>", "<reply text, without the @name>")
//
// It returns { posted, status } or { skipped, why }. The rules it keeps:
// - reply under the TOP-LEVEL comment (a reply to a nested reply silently fails);
// - SKIP when fpsacha already answered that comment with @name (the nightly pass
//   and the daytime session both answer: check first, never post twice);
// - the proof of a post is the fetch status, 201. The page and its "Comments (N)"
//   lag after a post: a reply missing after a reload is NOT a failure. Never retry
//   on that evidence; with no status, wait a full minute and reload twice first.
// - a reply already there that is now wrong gets one new reply that starts
//   "I got that wrong" (pass { correction: true }); never a second copy.

window.__mannersPosts = window.__mannersPosts || [];
if (!window.__mannersFetchWrapped) {
	const original = window.fetch;
	window.fetch = async (...args) => {
		const response = await original(...args);
		try {
			const method = (args[1] && args[1].method) || "GET";
			const url = String(args[0] && args[0].url || args[0]);
			if (method === "POST" && url.includes("/api/v1/comments")) {
				window.__mannersPosts.push(response.status);
			}
		} catch (e) { /* the record is a convenience */ }
		return response;
	};
	window.__mannersFetchWrapped = true;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function topLevel(author, snippet) {
	return [...document.querySelectorAll(".comment-body")].find((b) =>
		b.innerText.startsWith(author) && b.innerText.includes(snippet)
		&& !b.parentElement.className.includes("reply"));
}

function answeredAlready(body, author) {
	// The replies under a top-level comment follow it in document order.
	const all = [...document.querySelectorAll(".comment-body")];
	for (let i = all.indexOf(body) + 1; i < all.length; i++) {
		const b = all[i];
		if (!b.parentElement.className.includes("reply")) break;
		if (b.innerText.startsWith("fpsacha") && b.innerText.includes("@" + author)) return true;
	}
	return false;
}

window.mannersReply = async (author, snippet, text, options) => {
	options = options || {};
	for (const more of document.querySelectorAll(".comment-body .read-more-button")) more.click();
	await sleep(800);
	const body = topLevel(author, snippet);
	if (!body) return { skipped: true, why: "no top-level comment by " + author + " with that text on this page" };
	if (answeredAlready(body, author) && !options.correction) {
		return { skipped: true, why: "already answered by fpsacha" };
	}
	const reply = [...body.querySelectorAll("button")].find((b) => b.textContent.trim() === "Reply");
	if (!reply) return { skipped: true, why: "no Reply button" };
	reply.click();
	await sleep(1500);
	const box = [...document.querySelectorAll("textarea#post-comment-text")].find((t) => t.value.startsWith("@" + author));
	if (!box) return { skipped: true, why: "no reply box opened" };
	box.focus();
	Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, "value").set.call(box, "@" + author + " " + text);
	box.dispatchEvent(new InputEvent("input", { bubbles: true, inputType: "insertText" }));
	box.dispatchEvent(new Event("change", { bubbles: true }));
	box.blur();
	await sleep(800);
	let post = null;
	for (let node = box, i = 0; i < 6 && !post; i++) {
		node = node.parentElement;
		post = [...node.querySelectorAll("button")].find((b) => b.textContent.trim() === "Post");
	}
	if (!post) return { skipped: true, why: "no Post button" };
	const before = window.__mannersPosts.length;
	post.click();
	for (let i = 0; i < 20 && window.__mannersPosts.length === before; i++) await sleep(500);
	const status = window.__mannersPosts[before];
	return { posted: status === 201, status: status === undefined ? "no status yet: do NOT retry; reload twice a minute apart and look" : status };
};
"mannersReply ready";
