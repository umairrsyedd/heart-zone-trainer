# Privacy Policy for Heart Zone Trainer

This directory contains the privacy policy HTML file that can be hosted online for Play Store submission.

## File Structure

```
privacy-policy/
├── index.html          # Main privacy policy page
└── README.md          # This file
```

## Hosting Options

### Option 1: GitHub Pages (Recommended - Free)

1. **Create a new GitHub repository:**
   ```bash
   # On GitHub, create a new repo called:
   heart-zone-trainer-privacy
   ```

2. **Upload the files:**
   ```bash
   git init
   git add index.html README.md
   git commit -m "Add privacy policy"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/heart-zone-trainer-privacy.git
   git push -u origin main
   ```

3. **Enable GitHub Pages:**
   - Go to repository Settings → Pages
   - Source: Deploy from a branch
   - Branch: `main` / `root`
   - Click Save

4. **Your privacy policy URL will be:**
   ```
   https://YOUR_USERNAME.github.io/heart-zone-trainer-privacy/
   ```

### Option 2: Google Sites (Free)

1. Go to [sites.google.com](https://sites.google.com)
2. Click "Create" → "New site"
3. Copy the content from `index.html` and paste into the site
4. Publish the site
5. Copy the published URL

### Option 3: Netlify (Free)

1. Go to [netlify.com](https://netlify.com)
2. Drag and drop the `privacy-policy` folder
3. Get your URL: `https://random-name.netlify.app`
4. You can customize the domain name

### Option 4: Vercel (Free)

1. Go to [vercel.com](https://vercel.com)
2. Import the repository or upload the folder
3. Deploy automatically
4. Get your URL

### Option 5: Your Own Domain

If you have a website, simply upload `index.html` to your web server.

## After Hosting

1. **Save the URL** - You'll need it for Play Store submission
2. **Test the URL** - Make sure it's accessible and displays correctly
3. **Update the email** - Replace `umair@example.com` with your actual contact email in `index.html`

## Play Store Submission

When submitting to Google Play Store, you'll be asked for:
- **Privacy Policy URL**: Enter your hosted URL here
- **Data Safety Form**: Use the information from this privacy policy to fill out the form

## Updating the Privacy Policy

If you need to update the policy:

1. Edit `index.html`
2. Update the "Last Updated" date
3. Re-upload to your hosting service
4. The changes will be live immediately

## Notes

- The privacy policy uses the app's color scheme (dark theme matching the app)
- All styling is embedded in the HTML (no external dependencies)
- The page is mobile-responsive
- Make sure to replace `umair@example.com` with your actual contact email before hosting

