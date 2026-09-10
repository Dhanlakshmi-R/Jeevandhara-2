# Jeevandhara 2 — Week 1 Scaffold

This is the foundational plumbing for the project: repo structure,
database schema, JWT authentication, and a bare-bones Flutter app shell
(login → home with placeholder tiles for all 6 objectives). Every
future objective plugs into this.

## Structure

```
jeevandhara2-setup/
├── backend/     FastAPI + SQLAlchemy + JWT auth (see backend/README.md)
└── frontend/    Flutter app shell (see frontend/README.md)
```

## Getting this into your GitHub repo

You already have `Jeevandhara-2` cloned/created on GitHub. From your
own machine (not this chat, since I don't have network access to push
for you):

```bash
git clone https://github.com/Dhanlakshmi-R/Jeevandhara-2.git
cd Jeevandhara-2

# copy the backend/ and frontend/ folders from this download into here,
# so your repo looks like:
#   Jeevandhara-2/
#     backend/
#     frontend/
#     README.md

git add .
git commit -m "Week 1: project setup, DB schema, JWT auth, app shell"
git push origin main
```

Also add a `.gitignore` (if you don't have one) so you don't
accidentally commit secrets or build artifacts:

```
# backend
backend/venv/
backend/__pycache__/
backend/.env
backend/*.db

# frontend (Flutter)
frontend/.dart_tool/
frontend/.flutter-plugins
frontend/.flutter-plugins-dependencies
frontend/build/
```

## Try it end-to-end

1. Start the backend (`backend/README.md`) — confirm at `/docs`.
2. Run the Flutter app (`frontend/README.md`) — register a farmer
   account, log in, and you should land on the home screen showing
   your name and the 6 objective tiles.

Once that works, you're ready to start Week 2 (Objectives 1 & 2 —
weather alerts and crop prices).
