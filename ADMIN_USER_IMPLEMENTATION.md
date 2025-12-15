# Admin and User Implementation Guide

## Overview
The app now has **clear separation** between Admin and User flows with dedicated registration and login screens.

## Implementation Summary

### ✅ Flutter App Structure

#### Authentication Screens:
1. **User Login Screen** (`auth/login_screen.dart`)
   - Regular user login
   - "Sign In as Admin" button → navigates to Admin Login
   - "Register" link → navigates to User Registration

2. **User Registration Screen** (`auth/user_register_screen.dart`)
   - OTP-based registration flow
   - Requires: Phone, Name, Email (optional), Password, Apartment Code, Wing, Flat Number, Floor, Flat Type
   - After registration: Status is "pending" (waits for admin approval)

3. **Admin Login Screen** (`auth/admin_login_screen.dart`)
   - Dedicated admin login
   - "Register as Admin" link → navigates to Admin Registration
   - "Back to User Login" button

4. **Admin Registration Screen** (`auth/admin_register_screen.dart`)
   - Simple registration (no OTP, no apartment code needed)
   - Requires: Phone, Name, Email (optional), Password
   - After registration: Status is "active" immediately

#### Dashboard Screens:
1. **User Home Screen** (`home/home_screen.dart`)
   - For residents/staff
   - Shows: Quick actions, complaints, payments, notices, events

2. **Admin Dashboard Screen** (`admin/admin_dashboard_screen.dart`)
   - For admins
   - Shows: Stats (pending approvals, complaints), Quick actions

### ✅ Backend Structure

#### Authentication Routes:
- `POST /api/auth/password-login` - User login
- `POST /api/auth/admin/login` - Admin login
- `POST /api/auth/admin/register` - Admin registration
- `POST /api/auth/verify-otp-register` - User registration (with OTP)

#### Admin Routes:
- `GET /api/admin/dashboard` - Admin dashboard data
- `GET /api/admin/pending-approvals` - Get pending user approvals
- `PUT /api/admin/users/:userId/approval` - Approve/reject users
- `GET /api/admin/complaints` - Get all complaints
- `POST /api/admin/apartments` - Create apartment

## User Flow

### Resident/User Registration:
1. User clicks "Register" on login screen
2. Fills in personal details + apartment details
3. Sends OTP to phone
4. Verifies OTP
5. Account created with status "pending"
6. Waits for admin approval
7. Once approved, can login

### Resident/User Login:
1. Enter phone number and password
2. System checks role
3. If role = "resident" or "staff" → Navigate to HomeScreen
4. If role = "admin" → Navigate to AdminDashboardScreen

## Admin Flow

### Admin Registration:
1. Admin clicks "Sign In as Admin" → Admin Login Screen
2. Clicks "Register as Admin"
3. Fills in: Name, Phone, Email (optional), Password
4. Account created with status "active" immediately
5. Can create apartment after registration

### Admin Login:
1. Enter phone number and password
2. System checks role
3. Navigate to AdminDashboardScreen

## Role-Based Navigation

### After Login:
- **Admin** → `AdminDashboardScreen`
- **Resident/Staff** → `HomeScreen`

### Splash Screen:
- Checks if user is logged in
- Fetches user data from API
- Routes based on role:
  - Admin → Admin Dashboard
  - Others → User Home

## Key Features

### ✅ Clear Separation:
- Separate login screens for Admin and User
- Separate registration flows
- Different dashboards based on role

### ✅ Data Storage:
- User data stored as JSON string in SharedPreferences
- Token stored separately
- Role checked on app launch

### ✅ Backend Integration:
- All API endpoints properly configured
- Admin routes protected with `requireAdmin` middleware
- User routes protected with `protect` middleware

## Testing Checklist

### User Registration:
- [ ] Can register with OTP
- [ ] Status is "pending" after registration
- [ ] Cannot login until approved

### User Login:
- [ ] Can login with phone/password
- [ ] Navigates to HomeScreen
- [ ] Cannot access admin routes

### Admin Registration:
- [ ] Can register without OTP
- [ ] Status is "active" immediately
- [ ] Can login right away

### Admin Login:
- [ ] Can login with phone/password
- [ ] Navigates to AdminDashboardScreen
- [ ] Can access admin routes

### Role-Based Navigation:
- [ ] Splash screen routes correctly
- [ ] Login routes correctly
- [ ] Cannot access wrong dashboard

## Next Steps

1. **Complete Admin Dashboard:**
   - Implement pending approvals screen
   - Implement complaint management screen
   - Implement settings screen

2. **Complete User Features:**
   - Implement complaint creation
   - Implement payment flow
   - Implement notice viewing

3. **Add Role Guards:**
   - Prevent users from accessing admin screens
   - Prevent admins from accessing user-only features

