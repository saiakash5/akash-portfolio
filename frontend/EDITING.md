# How to edit your site content

Everything the site says lives in **one file**: [`src/data/profile.js`](src/data/profile.js).
You never need to touch the React components to change content.

After editing, see your changes instantly with:

```bash
cd frontend
npm run dev        # opens http://localhost:5173, live-reloads as you save
```

And publish with:

```bash
npm run build
aws s3 sync dist s3://akash-portfolio-frontend-20260612165153828900000001 --delete
aws cloudfront create-invalidation --distribution-id EI2XG1XSY296Y --paths "/*"
```

---

## Recipes

### Change the intro / summary / chips

Edit the `profile` object at the top. `facts` are the little pill chips under
your summary — add or remove strings freely.

### Add a new job

Copy this into the top of the `experience` array:

```js
{
  company: "Company Name",
  location: "City, ST",
  role: "Your Title",
  period: "2026 – Present",
  stack: ["Tech", "You", "Used"],
  highlights: [
    "Something impressive you did.",
    "Another thing.",
  ],
},
```

### Add a new project

Copy this into the `projects` array (`link` is optional — remove the line to
render plain text instead of a link):

```js
{
  name: "Project Name",
  description: "One or two sentences about it.",
  tags: ["Tag1", "Tag2"],
  link: "https://github.com/you/repo",
},
```

### Add a whole new section (custom block)

This is the `extras` array at the bottom — each entry becomes its own section
on the page, after Skills. Only `title` is required:

```js
{
  title: "Beyond the Code",
  body: [
    "A paragraph about hobbies, interests, whatever you like.",
    "A second paragraph if you want one.",
  ],
  tags: ["Cricket", "Cooking"],                          // optional chips
  links: [{ label: "My blog", url: "https://..." }],     // optional links
},
```

### Add a skill / certification / education entry

All plain arrays in the same file — follow the shape of what's already there.

---

## Where the look & feel lives (if you get curious)

- Colors, fonts, spacing: `src/index.css` — the `:root` block at the top holds
  the whole color palette as variables.
- Page structure / section order: `src/App.jsx` — reorder the components to
  reorder the page.
