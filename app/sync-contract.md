# Haiku Web Sync Contract

The web app is local-first and can run without a backend. To connect it to the iPhone app, set `window.HAIKU_SYNC_API_BASE` before `app.js` loads and provide the endpoints below.

## Pairing

The browser generates a short code and QR payload:

```text
https://haikuclock.app/pair?code=R8QHGZ&browser=<browser-id>
```

The iPhone app scans the QR or accepts the code, then asks the backend to approve that browser.

```http
POST /pairings/:code/confirm
Authorization: Bearer <iphone-user-token>
Content-Type: application/json

{
  "browserId": "<browser-id>",
  "browserName": "Chrome on Windows",
  "expiresAt": "2026-05-05T20:10:00.000Z"
}
```

The browser polls with the same code and browser id.

```http
GET /pairings/:code
X-Haiku-Browser-Id: <browser-id>
```

When approved:

```json
{
  "deviceToken": "long-lived-browser-token"
}
```

## Task Snapshot

The browser pushes a complete task snapshot.

```http
PUT /sync/tasks
Authorization: Bearer <long-lived-browser-token>
Content-Type: application/json

{
  "schemaVersion": 1,
  "modifiedAt": "2026-05-05T20:10:00.000Z",
  "tasks": [
    {
      "id": "uuid",
      "dateKey": "2026-05-05",
      "title": "Deep work",
      "startMinutes": 540,
      "endMinutes": 630,
      "color": "#607A67",
      "categoryId": "deep-work",
      "categoryName": "Deep Work",
      "isCompleted": false,
      "repeatFrequency": "never"
    }
  ]
}
```

The iPhone app can map these fields directly to `ClockTask` plus the selected calendar date.
