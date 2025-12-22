# Firebase Management Guide

This guide covers managing Firebase projects and services using both gcloud CLI and the Firebase CLI.

## Understanding the Firebase/GCP Relationship

Firebase projects are Google Cloud projects with Firebase-specific services enabled. Management requires:
- **gcloud CLI**: For GCP infrastructure (Firestore, Cloud Storage, IAM, etc.)
- **Firebase CLI**: For Firebase-specific features (Hosting, Functions, Rules, etc.)

## Firebase CLI Setup

### Installation

```bash
# Via npm (recommended)
npm install -g firebase-tools

# Via standalone binary
curl -sL https://firebase.tools | bash

# Verify installation
firebase --version
```

### Authentication

```bash
# Interactive login (opens browser)
firebase login

# Login without browser (for CI)
firebase login --no-localhost

# CI token generation
firebase login:ci
# Outputs token for CI_TOKEN environment variable

# Use token in CI
export FIREBASE_TOKEN="your-ci-token"
firebase deploy
```

### Project Management

```bash
# List projects
firebase projects:list

# Set active project
firebase use PROJECT_ID

# Create project alias
firebase use --add
# Interactive: set alias like "production" or "staging"

# Switch between aliases
firebase use production
firebase use staging
```

## Firebase Initialization

Initialize Firebase in your project directory:

```bash
firebase init
```

This creates:
- `firebase.json`: Project configuration
- `.firebaserc`: Project aliases
- Service-specific files (rules, functions directory, etc.)

**Select features:**
- Functions: Cloud Functions for Firebase
- Hosting: Static web hosting
- Firestore: Database rules and indexes
- Storage: Cloud Storage rules
- Emulators: Local development

## Cloud Functions Deployment

### Basic Function

Create `functions/index.js`:

```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// HTTP function
exports.helloWorld = functions.https.onRequest((req, res) => {
  res.json({ message: 'Hello from Firebase!' });
});

// Firestore trigger
exports.onUserCreate = functions.firestore
  .document('users/{userId}')
  .onCreate((snap, context) => {
    const user = snap.data();
    console.log('New user:', context.params.userId, user);
    return null;
  });

// Scheduled function
exports.dailyCleanup = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    console.log('Running daily cleanup');
    // Cleanup logic
    return null;
  });
```

### Deploy Functions

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:helloWorld

# Deploy multiple functions
firebase deploy --only functions:helloWorld,functions:onUserCreate
```

### Function Configuration

```bash
# Set environment config
firebase functions:config:set someservice.key="API_KEY" someservice.url="https://api.example.com"

# Get config
firebase functions:config:get

# Unset config
firebase functions:config:unset someservice.key

# Use in code:
# const config = functions.config();
# const apiKey = config.someservice.key;
```

### Functions with Runtime Options

```javascript
exports.memoryIntensive = functions
  .runWith({
    memory: '1GB',
    timeoutSeconds: 300,
    maxInstances: 10
  })
  .https.onRequest((req, res) => {
    // Heavy processing
  });
```

## Firebase Hosting

### Configuration

Edit `firebase.json`:

```json
{
  "hosting": {
    "public": "public",
    "ignore": [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ],
    "rewrites": [
      {
        "source": "/api/**",
        "function": "api"
      },
      {
        "source": "**",
        "destination": "/index.html"
      }
    ],
    "headers": [
      {
        "source": "**/*.@(js|css)",
        "headers": [
          {
            "key": "Cache-Control",
            "value": "max-age=31536000"
          }
        ]
      }
    ]
  }
}
```

### Deploy Hosting

```bash
# Deploy hosting only
firebase deploy --only hosting

# Deploy to specific site (multi-site setup)
firebase deploy --only hosting:my-site

# Preview before deploy
firebase hosting:channel:deploy preview --expires 7d

# Deploy with message
firebase deploy --only hosting -m "Release v1.2.0"
```

### Serve Locally

```bash
# Serve hosting locally
firebase serve --only hosting

# Serve with functions
firebase serve --only hosting,functions
```

## Security Rules Deployment

### Firestore Rules

Create `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Helper functions
    function isAuthenticated() {
      return request.auth != null;
    }

    function isOwner(userId) {
      return request.auth.uid == userId;
    }

    // Users collection
    match /users/{userId} {
      allow read: if isAuthenticated();
      allow write: if isOwner(userId);
    }

    // Public posts
    match /posts/{postId} {
      allow read: if true;
      allow create: if isAuthenticated()
        && request.resource.data.authorId == request.auth.uid;
      allow update, delete: if isAuthenticated()
        && resource.data.authorId == request.auth.uid;
    }

    // Admin-only collection
    match /admin/{document=**} {
      allow read, write: if request.auth.token.admin == true;
    }
  }
}
```

### Deploy Rules

```bash
# Deploy Firestore rules
firebase deploy --only firestore:rules

# Deploy Storage rules
firebase deploy --only storage

# Deploy all rules
firebase deploy --only firestore:rules,storage
```

### Storage Rules

Create `storage.rules`:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {

    // User uploads
    match /users/{userId}/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.uid == userId
        && request.resource.size < 5 * 1024 * 1024
        && request.resource.contentType.matches('image/.*');
    }

    // Public assets
    match /public/{allPaths=**} {
      allow read: if true;
      allow write: if request.auth.token.admin == true;
    }
  }
}
```

### Firestore Indexes

Create `firestore.indexes.json`:

```json
{
  "indexes": [
    {
      "collectionGroup": "posts",
      "queryScope": "COLLECTION",
      "fields": [
        { "fieldPath": "authorId", "order": "ASCENDING" },
        { "fieldPath": "createdAt", "order": "DESCENDING" }
      ]
    }
  ],
  "fieldOverrides": []
}
```

Deploy indexes:

```bash
firebase deploy --only firestore:indexes
```

## Firestore with gcloud

### Export Data

```bash
# Export entire database
gcloud firestore export gs://my-bucket/firestore-backup

# Export specific collections
gcloud firestore export gs://my-bucket/firestore-backup \
  --collection-ids=users,posts

# Export to specific path
gcloud firestore export gs://my-bucket/backups/$(date +%Y%m%d)
```

### Import Data

```bash
# Import from backup
gcloud firestore import gs://my-bucket/firestore-backup

# Import specific collections
gcloud firestore import gs://my-bucket/firestore-backup \
  --collection-ids=users
```

### Manage Indexes with gcloud

```bash
# List indexes
gcloud firestore indexes composite list

# Create index
gcloud firestore indexes composite create \
  --collection-group=posts \
  --field-config=field-path=authorId,order=ascending \
  --field-config=field-path=createdAt,order=descending

# Delete index
gcloud firestore indexes composite delete INDEX_ID
```

## Firebase Test Lab (gcloud)

Test mobile apps on real devices:

```bash
# Run Robo test on Android
gcloud firebase test android run \
  --app build/app-debug.apk \
  --device model=Pixel6,version=33,locale=en_US \
  --timeout 90s

# Run instrumentation test
gcloud firebase test android run \
  --app build/app-debug.apk \
  --test build/app-debug-androidTest.apk \
  --device model=Pixel6,version=33

# Run iOS test
gcloud firebase test ios run \
  --test build/ios_tests.zip \
  --device model=iphone13pro,version=15.2
```

## Firebase Emulators

### Configure Emulators

Edit `firebase.json`:

```json
{
  "emulators": {
    "functions": {
      "port": 5001
    },
    "firestore": {
      "port": 8080
    },
    "hosting": {
      "port": 5000
    },
    "auth": {
      "port": 9099
    },
    "storage": {
      "port": 9199
    },
    "ui": {
      "enabled": true,
      "port": 4000
    }
  }
}
```

### Start Emulators

```bash
# Start all emulators
firebase emulators:start

# Start specific emulators
firebase emulators:start --only functions,firestore

# Export data on shutdown
firebase emulators:start --export-on-exit=./emulator-data

# Import data on startup
firebase emulators:start --import=./emulator-data
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Deploy to Firebase

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        working-directory: ./functions
        run: npm ci

      - name: Deploy to Firebase
        uses: w9jds/firebase-action@master
        with:
          args: deploy --only functions,hosting
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

### Cloud Build

Create `cloudbuild.yaml`:

```yaml
steps:
  # Install dependencies
  - name: 'node:20'
    dir: 'functions'
    entrypoint: npm
    args: ['ci']

  # Deploy to Firebase
  - name: 'us-docker.pkg.dev/firebase-cli/us/firebase'
    args:
      - 'deploy'
      - '--project=$PROJECT_ID'
      - '--only=functions,hosting'
    env:
      - 'FIREBASE_TOKEN=${_FIREBASE_TOKEN}'

substitutions:
  _FIREBASE_TOKEN: ''
```

## Multiple Environments

### Using Aliases

```bash
# Set up aliases
firebase use --add
# Select dev project, alias: dev
firebase use --add
# Select prod project, alias: prod

# Deploy to specific environment
firebase use dev
firebase deploy

firebase use prod
firebase deploy
```

### Environment-Specific Config

```bash
# Set config per environment
firebase use dev
firebase functions:config:set app.environment="development" app.debug="true"

firebase use prod
firebase functions:config:set app.environment="production" app.debug="false"
```

## Required IAM Roles

### For Firebase Admin

```bash
# Full Firebase access
roles/firebase.admin

# Firebase deployment
roles/firebase.developAdmin

# Firestore access
roles/datastore.owner
```

### Grant Firebase Permissions

```bash
gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="user:developer@example.com" \
  --role="roles/firebase.developAdmin"

gcloud projects add-iam-policy-binding PROJECT_ID \
  --member="serviceAccount:ci@PROJECT.iam.gserviceaccount.com" \
  --role="roles/firebase.admin"
```

## Troubleshooting

### Deployment Failures

```bash
# Check function logs
firebase functions:log

# Verbose deployment
firebase deploy --debug

# Check project configuration
firebase projects:list
cat .firebaserc
```

### Rules Not Applied

```bash
# Deploy rules explicitly
firebase deploy --only firestore:rules

# Check deployed rules
# Visit Firebase Console > Firestore > Rules
```

### Emulator Issues

```bash
# Clear emulator data
rm -rf ./emulator-data

# Start with fresh state
firebase emulators:start --clear-persistence

# Check ports
lsof -i :8080  # Firestore
lsof -i :5001  # Functions
```
