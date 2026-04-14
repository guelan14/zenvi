# Zervi

Zervi is a premium service marketplace app for Posadas, Misiones, built with **Flutter**, **Supabase**, and **Riverpod**.

## Features
- **Antigravity UI**: Modern, premium design with high-radius cards and soft shadows.
- **Dual Feed**: Easily toggle between "Services" and "Jobs".
- **Real-time Messaging**: Instant communication between clients and professionals via Supabase.
- **Cross-platform**: Support for Windows, Web, and Mobile.

## Tech Stack
- **Framework**: Flutter
- **State Management**: Riverpod
- **Backend**: Supabase
- **Analytics**: PostHog
- **Routing**: GoRouter
- **Typography**: Manrope (via Google Fonts)

## Getting Started

1. Clone the repository.
2. Run `flutter pub get`.
3. Create a `.env` file in the root using `.env.example` as a template.
4. Add your Supabase URL and Anon Key to the `.env` file.
5. **Database Setup**:
   - Go to your Supabase Dashboard -> SQL Editor.
   - Copy the contents of `supabase/schema.sql` and run them.
   - This will create all necessary tables, enums, and initial categories.
6. Run the app: `flutter run`.
