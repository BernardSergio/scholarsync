Project Description

AURA is a secure application designed to be a private partner for individuals managing HIV treatment and prevention. In a context where social stigma can be a significant barrier to consistent care, AURA provides a confidential, stigma-free digital environment. The app operates as a standalone unit on the user's device, ensuring that all sensitive data—including medication logs, health journals, and appointments—is encrypted and never leaves the device without explicit user consent. By combining discreet, intelligent reminders with a robust privacy-first architecture, AURA empowers users to manage their health with confidence and peace of mind.

Key Features
- Fortified Authentication & Security: Secure login with passphrase, optional Two-Factor Authentication (2FA), and auto-lock timer. Accounts are temporarily locked after 5 failed attempts.
- Home Dashboard & Analytics: An at-a-glance overview featuring a Current Mood tracker, Medication Adherence progress bar, and an Adherence Calendar with color-coded logs (Green: Taken, Red: Missed, Gray: No data).
- Encrypted Journal Vault: A private, encrypted diary for logging Mood, Medications, Side Effects, and Notes. Entries can be filtered, tagged, and exported as an encrypted backup.
- Smart Reminders & Scheduling: Manages medication schedules and healthcare appointments with discreet, intelligent reminders and status indicators (Pending, Taken, Missed).
- Integrated Resources: An offline-accessible directory of nearby clinics, pharmacies, educational articles, and emergency hotlines, with quick-dial and directions functionality.
- Discreet Customization: Options to choose from subtle, neutral app icons to maintain a low profile on the device's home screen.

Technology Stack
- Frontend: Flutter (Dart)
- Backend: Node.js
- Database: MongoDB with Mongoose ODM
- Authentication: JSON Web Tokens (JWT)
- Security: Bcrypt for password hashing, Input Validation, Environment Variables

System Architecture
The system is structured into three main layers:
1. Frontend Layer (Flutter): Manages the entire user interface, built for cross-platform compatibility.
2. Backend Layer (Node.js): A modular RESTful API with Routes, Controllers, Models, and Middleware for JWT verification.
3. Database Layer (MongoDB): Persists all application data with Mongoose ensuring data validation and a structured query interface.

