# NahidOS — Nahid Hasan's résumé

A résumé you can click around in: a Windows 95 desktop, art-directed in the present
day, that boots into a portfolio. Double-click the icons — or tap them, it works on
phones too.

**Nahid Hasan** — Senior Software Engineer, Dhaka, Bangladesh. Full-stack since 2017,
for Japanese, US and Canadian clients.
[nahidhasan.online](https://nahidhasan.online)

## What's here

```
index.html              the whole site — one file, no build step
assets/fonts.css        @font-face rules (the font files load from Google Fonts)
assets/img/             portrait, share-preview cover, project screenshots
                        (.webp is what the site serves; projects/original/ keeps
                        the full-res masters)
resume/                 Nahid_Hasan_CV.docx and .pdf
documents/Projects.md   every project, in the same wording as the CV
robots.txt, sitemap.xml for crawlers
deployment/deploy.sh    rsync + nginx + certificate for the EC2 box
vercel.json             the same redirect, caching and headers, for Vercel
```

## Running it

Open `index.html` in a browser — that's it.

One caveat: the Video CV player embeds YouTube, and YouTube refuses to embed from a
`file://` page (error 153). Opened that way the player detects it and opens YouTube in
a new tab instead. To see it play inline, serve the folder over HTTP:

```sh
python3 -m http.server 8000   # then visit http://localhost:8000
```

## Deploying

```sh
./deployment/deploy.sh --dry-run      # show what would change, do nothing
./deployment/deploy.sh                # files only — safe, repeatable
./deployment/deploy.sh --with-nginx   # also install/refresh the vhost
./deployment/deploy.sh --with-ssl     # vhost + Let's Encrypt certificate
```

The script needs `rsync` and an SSH key for the server; host, user, key and domain can
be overridden with `DEPLOY_HOST`, `DEPLOY_USER`, `DEPLOY_KEY` and `DEPLOY_DOMAIN`.

The box also runs other live sites, so the script only ever adds. It checks the config
with `nginx -t` before reloading, disables its own vhost again if the check fails, and
confirms the other sites still answer afterwards.

Only what the site serves is uploaded: the full-res screenshot masters, this README,
`deployment/` and `vercel.json` stay behind.

## Notes

- **Nothing with a year in it goes stale.** `new Date().getFullYear()` drives the
  "Update to 20XX" button, the Now window, the footer and the time-travel animation,
  and years of experience are computed as `YEAR - 2017`. Project years and employment
  dates are real dates and stay fixed.
- **The résumé is in the HTML, not only in the JavaScript.** The desktop is painted by
  script, so a crawler would otherwise see icon labels and nothing else. A semantic
  `<main>` carries the full résumé — visually clipped rather than `display:none`, so it
  stays in the accessibility tree — alongside a canonical URL, Open Graph tags and
  `Person` JSON-LD.
- **Share previews can't run scripts.** WhatsApp, LinkedIn and Slack read the served
  HTML as-is, so the meta tags say "since 2017" instead of a computed year count.
- **Phones get the same desktop.** Below 760px the desktop becomes a scroller, the
  taskbar is pinned with `100dvh` and `safe-area-inset-bottom` so iOS Safari's toolbar
  and home indicator can't cover it, and Clippy stays home.
- **Analytics is Google Analytics 4.** The Measurement ID (`window.GA_ID` in the
  `<head>`) is the only thing to edit. Résumé PDF downloads are sent as a separate
  `resume_download` event.
- **Project covers fall back gracefully.** Each project renders its screenshot; if the
  image fails, a generated SVG tile takes its place, so nothing ever renders blank.
- **`documents/Projects.md` and the hidden `<main>` are generated from the CV**, which
  is why they never drift apart. Edit the CV, not the copies.

## Credit

The Windows 95 desktop concept and interaction design are adapted, with substantial
rework, from [robbyyeager.com](https://robbyyeager.com). All content, projects and
copy here are my own.

© 2026 Nahid Hasan. All rights reserved.
