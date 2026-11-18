# Dami Shop

A store (clothing, objects, shoes, paintings) with a real backend on
[Supabase](https://supabase.com): login is required, prices live on the server
(not in the page source), and orders are saved to the database.

## How it works

- **Logged out:** only the home page is visible. There are **no products or
  prices in the page source**, so they can't be read with "view source" /
  inspect.
- **Sign-up (one step):** full name, email, street and house number, postal
  code, phone and password in a single form. Supabase Auth creates the
  account, and a trigger in `db/schema.sql` creates the profile from the
  form data on the server.
- **Log in:** email + password.
- **After signing up / logging in:** the browser fetches the catalog and prices
  from Supabase and renders the store. Checkout is pre-filled with the
  street, postal code and phone from the profile.
- **Checkout:** orders are inserted into the `orders` table in Supabase and read
  back from there (not only from the browser). Cancel / refund updates the order
  status in the database.
- **Security:** Row Level Security (RLS) makes prices readable only by
  signed-in users, and each user can only see and change their own orders.
  The publishable key in `config.js` is safe to publish because of this.

## Setup

`config.js` already points to the Supabase project. In that project:

1. **SQL Editor → New query** → paste all of `db/schema.sql` → **Run**.
2. **New query** → paste all of `db/seed.sql` → **Run** (loads the 80 products
   only if the table is empty).
3. **New query** → paste all of `db/ui_text.sql` → **Run**.
4. Open `index.html`.

All three SQL files are safe to run again.

### Shared Supabase project
This project is also used by the clickjacking demo in `Documents/Dami Shop`.
`db/schema.sql` only adds tables, columns and policies, so the demo keeps
working.

### Email confirmation
If **Authentication → Sign In / Providers → Email → Confirm email** is on, new
users must click the link in the email before they can log in (the page tells
them). Turn it off to let people shop right after signing up.

## Files
- `index.html` — the whole store (UI + logic).
- `config.js` — Supabase URL and publishable key.
- `db/schema.sql` — tables, Row Level Security, policies and the sign-up trigger.
- `db/seed.sql` — the 80 products and their prices.
- `db/ui_text.sql` — texts for the cancel / refund dialogs.
