# NahidOS — Nahid Hasan's résumé

A résumé you can click around in: a Windows 95 desktop, art-directed in the present
day, that boots into a portfolio. Double-click the icons.

**Nahid Hasan** — Senior Software Engineer, Dhaka, Bangladesh. 9+ years full-stack for
international clients, including enterprise Japanese markets.
[nahidhasan.online](https://nahidhasan.online)

## What's here

```
index.html              the whole site — one file, no build step, no dependencies
assets/fonts.css        Google Fonts stylesheet
assets/img/             portrait + project screenshots (.webp, with full-res originals)
resume/                 Nahid_Hasan_CV.docx and .pdf
documents/Projects.md   every project, in the same wording as the CV
```

## Running it

Open `index.html` in a browser — that's it.

One caveat: the Video CV player embeds YouTube, and YouTube refuses to embed from a
`file://` page (error 153). Opened that way the player detects it and opens YouTube in
a new tab instead. To see it play inline, serve the folder over HTTP:

```sh
python3 -m http.server 8000   # then visit http://localhost:8000
```

## Notes

- **The branding year is dynamic.** `new Date().getFullYear()` drives the "Update to
  20XX" button, the Now window, the footer and the time-travel animation, so none of it
  goes stale. Project years and employment dates are real dates and stay fixed.
- **Project covers fall back gracefully.** Each project renders its screenshot; if the
  image fails, a generated SVG tile takes its place, so nothing ever renders blank.
- **`documents/Projects.md` is generated from the CV**, which is why the two never drift
  apart. Edit the CV, not the markdown.

## Credit

The Windows 95 desktop concept and interaction design are adapted, with substantial
rework, from [robbyyeager.com](https://robbyyeager.com). All content, projects and
copy here are my own.

© 2026 Nahid Hasan. All rights reserved.
