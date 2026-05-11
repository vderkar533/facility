# Integrated Service Management (React)

Login UI for the Facility/Integrated Service Management system.

## Prereqs

- Node.js 18+ recommended
- Backend running on `http://localhost:5003`

## Setup

```bash
cd frontend_react
npm.cmd install
npm.cmd run dev
```

The app runs on `http://localhost:3000`.
The configured dev port is `http://localhost:5004` from `.env`.

## Notes (Windows PowerShell)

If you see `npm.ps1 cannot be loaded because running scripts is disabled`, use `npm.cmd ...` as shown above (or change your PowerShell execution policy).

## Backend connection

Default dev setup uses `REACT_APP_API_BASE_URL` and `proxy` to call the backend at `http://localhost:5003`.

To override (e.g., different host), create an env var:

```bash
set REACT_APP_API_BASE_URL=http://localhost:5003
```
