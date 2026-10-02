              # FConnect - PRM393 Flutter Project

## 1. Project Overview

FConnect is a Food & Beverage (F&B) platform built as a Flutter mobile application.

The application supports two main user roles:

1. Customer
2. Business Owner

The application uses one Flutter codebase for both roles. After login, the application determines the user's role and displays the appropriate interface.

The project focuses on the core F&B customer journey:

> Discover F&B → View F&B → View Menu → View Product → Add to Cart → Checkout → Booking → Order → Notification → Chat with Business Owner

The application does NOT include AI Chatbot, Staff, Review/Rating, Delivery, Loyalty, Voucher, or other advanced features in the current PRM393 scope.

---

# 2. Project Goals

The main goals of the project are:

- Build a complete Flutter mobile application.
- Implement Customer and Business Owner roles.
- Demonstrate Provider state management.
- Connect Flutter to a REST API.
- Store application data in a remote MongoDB database through the backend.
- Implement authentication and role-based navigation.
- Implement F&B discovery.
- Implement product/menu management.
- Implement shopping cart and checkout.
- Implement table booking.
- Implement order management.
- Implement Customer ↔ Business Owner messaging.
- Implement notifications.
- Implement map-based F&B discovery.
- Demonstrate Unit Testing and Widget Testing.
- Build a release APK.

---

# 3. Technology Stack

## Mobile Application

- Flutter
- Dart
- Provider
- HTTP/REST API
- Material Design

## Backend

The Flutter application communicates with the backend through REST APIs.

Expected backend stack:

- Node.js
- Express
- REST API
- JWT Authentication

## Database

- MongoDB

Flutter must NOT connect directly to MongoDB.

The correct architecture is:

```text
Flutter
   ↓
Provider
   ↓
Service
   ↓
REST API
   ↓
Node.js Backend
   ↓
MongoDB
4. Application Roles
4.1 Customer

Customer is the normal F&B application user.

Customer can:

Register
Login
Logout
Manage profile
Search F&B
Filter F&B
View F&B near the user
View F&B on map
View F&B details
View menu
View products
Favorite F&B
Book a table
Add products to cart
Checkout
Create orders
Track orders
View booking history
View order history
Receive notifications
Chat with Business Owner
4.2 Business Owner

Business Owner uses the same Flutter application.

After login, the application detects:

role = BUSINESS_OWNER

and navigates to the Owner interface.

Business Owner can:

View dashboard
Manage business information
Manage menu
Manage products
Manage tables
Manage bookings
Manage orders
Chat with customers
Receive notifications

Business Owner does NOT have Staff accounts in the current scope.

5. Role-Based Navigation

The application uses one Flutter project.

Login flow:

Splash Screen
      ↓
Check Authentication
      ↓
Login
      ↓
Get User + Role
      ↓
 ┌───────────────┐
 │               │
Customer     Business Owner
 │               │
 ↓               ↓
Customer Home    Owner Dashboard

Example login response:

{
  "token": "JWT_TOKEN",
  "user": {
    "id": "USER_ID",
    "name": "John Doe",
    "email": "john@example.com",
    "role": "CUSTOMER"
  }
}

Possible roles:

CUSTOMER
BUSINESS_OWNER

The role must be stored in the authentication state.

6. Main Customer Features
6.1 Authentication

Screens:

Splash
Login
Register
Forgot Password
Profile

Customer authentication includes:

Email
Password
JWT token
Login persistence
Logout
7. Customer Home

The Home screen is the main discovery screen.

Recommended structure:

Home
│
├── Header
├── Search
├── Categories
├── Featured F&B
├── Nearby F&B
└── Map Preview

The Home screen should remain simple and focused on F&B discovery.

8. F&B Discovery

Customers can discover F&B locations.

Supported information:

Business name
Category
Cover image
Logo
Address
Distance
Opening hours
Price range
Favorite status

Possible F&B categories:

RESTAURANT
CAFE
MILK_TEA
BAKERY
FAST_FOOD
BBQ
BUFFET
DESSERT
BAR
OTHER
9. Search

Customers can search for F&B locations.

Search criteria may include:

Business name
Category
Location

Example:

"BBQ"
"Coffee"
"Buffet"
"Milk Tea"

Search results should display F&B cards.

10. Filter

Supported filters:

Category
Price range
Distance
Open/Closed status

Filters should be implemented through Provider state.

Example:

SearchProvider
    ↓
keyword
category
priceRange
distance
isOpen
    ↓
API
    ↓
Search Results
11. Map

The Map screen displays F&B locations.

Main functions:

Show user location
Show F&B markers
Select F&B marker
View F&B information
Navigate to F&B detail

Flow:

Map
 ↓
F&B Marker
 ↓
F&B Preview
 ↓
F&B Detail

The map is a discovery feature.

12. F&B Detail

The F&B Detail screen is one of the main screens of the application.

It should display:

Cover image
Business name
Category
Address
Distance
Opening hours
Favorite button
Chat button
Booking button
Menu
Branch information

Example navigation:

F&B Detail
│
├── Favorite
├── Chat
├── Booking
└── Menu

The Chat and Booking buttons navigate to features owned by other modules.

13. Favorite

Customer can favorite an F&B.

Flow:

F&B Detail
    ↓
Favorite
    ↓
Favorites Screen

Rules:

One customer can favorite a business only once.
Unfavorite removes the relationship.
Favorite status must be reflected in the UI.
14. Menu

Each F&B branch can have one or more menus.

Structure:

Business
   ↓
Branch
   ↓
Menu
   ↓
Product

Example:

ABC Restaurant
    ↓
Main Menu
    ├── BBQ
    │    ├── Beef
    │    └── Pork
    │
    └── Drinks
         ├── Coca Cola
         └── Peach Tea
15. Product List

The Product List screen displays products belonging to a menu.

Each product can display:

Image
Name
Price
Category
Availability

Example:

[Image] Grilled Beef
        120,000 VND

[Image] Grilled Pork
        100,000 VND

This screen satisfies the PRM393 Product List requirement.

16. Product Detail

Product Detail displays:

Product image
Product name
Description
Price
Availability
Quantity
Product options

Example:

Traditional Milk Tea
35,000 VND

Size:
○ M
○ L +10,000 VND

Quantity:
[-] 2 [+]

[Add to Cart]

Product options should be handled dynamically when possible.

17. Shopping Cart

The Cart contains products selected by the customer.

Cart functions:

View items
Increase quantity
Decrease quantity
Remove item
Select options
Calculate subtotal
Calculate total

Example:

Traditional Milk Tea
2 x 35,000
= 70,000

BBQ Beef
1 x 120,000
= 120,000

----------------
Total: 190,000 VND

The Cart must use CartProvider.

18. Checkout

Checkout is the confirmation step before creating an order.

Checkout displays:

Business
Selected products
Quantities
Product options
Subtotal
Discount if supported
Total
Customer note

Flow:

Product
   ↓
Cart
   ↓
Checkout
   ↓
Confirm
   ↓
Create Order

Payment gateway is NOT required in the current PRM393 scope.

The application may treat checkout as order confirmation/billing rather than implementing a real online payment gateway.

19. Table Management

Business Owner can manage tables.

Table information:

Table
├── Name
├── Capacity
├── Area
└── Status

Example:

A01 - 4 people - Available
A02 - 2 people - Available
A03 - 6 people - Maintenance

Possible table statuses:

AVAILABLE
UNAVAILABLE
MAINTENANCE

Do not permanently store OCCUPIED as the main table state.

Occupancy should be derived from booking/order state when required.

20. Booking

Customers can book tables.

Booking flow:

F&B Detail
    ↓
Booking
    ↓
Select Date
    ↓
Select Time
    ↓
Guest Count
    ↓
Select Table
    ↓
Confirm

Booking information:

Customer
Business
Branch
Table
Date
Start time
End time
Guest count
Note
Status

Booking statuses:

PENDING
CONFIRMED
REJECTED
CANCELLED
CHECKED_IN
COMPLETED

The system should prevent overlapping bookings for the same table.

21. Business Owner Booking Management

Owner can view incoming bookings.

Example:

Booking #FCB001

Customer:
Nguyen Van A

Guests:
4

Date:
2026-10-01

Time:
19:00 - 21:00

Table:
A01

Status:
PENDING

Owner actions:

[Confirm]
[Reject]

After confirmation:

PENDING
   ↓
CONFIRMED
22. Ordering

Customers can create orders from their cart.

Supported order types:

PRE_ORDER
DINE_IN

Order statuses:

PENDING
CONFIRMED
PREPARING
READY
SERVED
COMPLETED
CANCELLED

Order flow:

Cart
 ↓
Checkout
 ↓
Create Order
 ↓
PENDING
 ↓
Owner confirms
 ↓
CONFIRMED
 ↓
PREPARING
 ↓
READY
 ↓
SERVED
 ↓
COMPLETED
23. Order Tracking

Customer can view the current order status.

Example:

Order #FCO001

✓ Order Created
✓ Confirmed
✓ Preparing
● Ready
○ Served
○ Completed

The UI should clearly communicate the current status.

24. Business Owner Order Management

Owner can:

View orders
View order details
Confirm order
Update preparation status
Mark order ready
Mark served
Complete order

Owner order screen:

Order #FCO001

Customer: Nguyen Van A

2x BBQ Beef
1x Coca Cola

Total:
250,000 VND

Status:
PREPARING

[Mark Ready]
25. Customer ↔ Business Owner Chat

Chat is a required feature.

There is NO AI Chatbot in the current scope.

The chat is between:

Customer ↔ Business Owner

Customer can start a conversation from F&B Detail.

Example:

F&B Detail
     ↓
Chat with Store
     ↓
Conversation

Example conversation:

Customer:
"Quán còn bàn 4 người lúc 7 giờ không?"

Owner:
"Dạ còn bàn A03 ạ."
26. Chat Features

Customer:

View conversations
Open conversation
Send message
Receive message
Mark messages as read

Business Owner:

View conversations
Open customer conversation
Send message
Receive message
Mark messages as read

Current MVP can use REST API.

Realtime messaging is optional unless explicitly required.

If realtime is implemented later, Socket.IO can be added.

27. Notifications

Notifications inform users about important system events.

Customer notifications:

Booking confirmed
Booking rejected
Booking cancelled
Order confirmed
Order ready
New chat message

Business Owner notifications:

New booking
New order
New chat message

Notification fields:

id
userId
type
title
message
referenceId
isRead
createdAt
28. Owner Dashboard

Business Owner has a simple dashboard.

Example:

Owner Dashboard

Hello, ABC Restaurant

Today's Bookings
12

Today's Orders
25

Unread Messages
5

Dashboard can display summary information from:

Bookings
Orders
Messages

The dashboard should not contain complicated analytics in the current MVP.

29. Business Owner Management

Owner can manage:

Business
Business name
Description
Logo
Cover
Category
Price range
Branch
Branch name
Phone
Address
Location
Opening hours
Images
Menu
Create
Update
Delete
Product
Create
Update
Delete
Change price
Change availability
Table
Create
Update
Delete
Capacity
Status
30. Database Collections

Main MongoDB collections:

users
businesses
branches
menus
products
tables
bookings
carts
orders
favorites
notifications
conversations
messages

The Flutter application must never directly access MongoDB.

31. User Model

Example:

{
  "_id": "ObjectId",
  "name": "Nguyen Van A",
  "email": "user@example.com",
  "password": "hashed_password",
  "phone": "0900000000",
  "avatarUrl": "...",
  "role": "CUSTOMER",
  "createdAt": "Date",
  "updatedAt": "Date"
}

Roles:

CUSTOMER
BUSINESS_OWNER
32. Business Model
{
  "_id": "ObjectId",
  "ownerId": "ObjectId",
  "name": "ABC Restaurant",
  "slug": "abc-restaurant",
  "description": "...",
  "categories": [
    "RESTAURANT",
    "BBQ"
  ],
  "logoUrl": "...",
  "coverImageUrl": "...",
  "priceRange": {
    "min": 50000,
    "max": 300000
  },
  "status": "APPROVED",
  "createdAt": "Date",
  "updatedAt": "Date"
}

Business status:

PENDING
APPROVED
REJECTED
SUSPENDED
33. Branch Model
{
  "_id": "ObjectId",
  "businessId": "ObjectId",
  "name": "ABC Restaurant - Hai Chau",
  "phone": "...",
  "address": {
    "street": "...",
    "ward": "...",
    "district": "Hai Chau",
    "city": "Da Nang"
  },
  "location": {
    "type": "Point",
    "coordinates": [
      108.218,
      16.047
    ]
  },
  "openingHours": [
    {
      "dayOfWeek": 1,
      "open": "07:00",
      "close": "22:00",
      "isClosed": false
    }
  ],
  "status": "ACTIVE",
  "createdAt": "Date",
  "updatedAt": "Date"
}

GeoJSON coordinates must use:

[longitude, latitude]
34. Menu Model
{
  "_id": "ObjectId",
  "businessId": "ObjectId",
  "branchId": "ObjectId",
  "name": "Main Menu",
  "description": "...",
  "status": "ACTIVE",
  "createdAt": "Date",
  "updatedAt": "Date"
}
35. Product Model
{
  "_id": "ObjectId",
  "businessId": "ObjectId",
  "branchId": "ObjectId",
  "menuId": "ObjectId",
  "category": "BBQ",
  "name": "Grilled Beef",
  "description": "...",
  "price": 120000,
  "imageUrl": "...",
  "options": [
    {
      "name": "Size",
      "required": true,
      "values": [
        {
          "name": "M",
          "price": 0
        },
        {
          "name": "L",
          "price": 20000
        }
      ]
    }
  ],
  "isAvailable": true,
  "preparationTime": 15,
  "createdAt": "Date",
  "updatedAt": "Date"
}

Product options are embedded in the Product document.

36. Table Model
{
  "_id": "ObjectId",
  "branchId": "ObjectId",
  "name": "A01",
  "capacity": 4,
  "area": "Floor 1",
  "status": "AVAILABLE",
  "createdAt": "Date",
  "updatedAt": "Date"
}
37. Booking Model
{
  "_id": "ObjectId",
  "userId": "ObjectId",
  "businessId": "ObjectId",
  "branchId": "ObjectId",
  "tableId": "ObjectId",
  "bookingCode": "FCB202610001",
  "bookingDate": "2026-10-01",
  "startTime": "19:00",
  "endTime": "21:00",
  "guestCount": 4,
  "status": "CONFIRMED",
  "note": "Birthday",
  "checkedInAt": null,
  "completedAt": null,
  "createdAt": "Date",
  "updatedAt": "Date"
}
38. Cart Model

Cart belongs to one customer and one branch.

{
  "_id": "ObjectId",
  "userId": "ObjectId",
  "branchId": "ObjectId",
  "items": [
    {
      "productId": "ObjectId",
      "quantity": 2,
      "selectedOptions": [
        {
          "name": "Size",
          "value": "L",
          "additionalPrice": 20000
        }
      ]
    }
  ],
  "updatedAt": "Date"
}

Do not mix products from different businesses in the same cart.

39. Order Model
{
  "_id": "ObjectId",
  "orderCode": "FCO202610001",
  "userId": "ObjectId",
  "businessId": "ObjectId",
  "branchId": "ObjectId",
  "bookingId": "ObjectId",
  "tableId": "ObjectId",
  "orderType": "PRE_ORDER",
  "items": [
    {
      "productId": "ObjectId",
      "productName": "Grilled Beef",
      "unitPrice": 120000,
      "quantity": 2,
      "selectedOptions": [
        {
          "name": "Size",
          "value": "L",
          "additionalPrice": 20000
        }
      ],
      "subtotal": 280000
    }
  ],
  "subtotal": 280000,
  "discount": 0,
  "total": 280000,
  "status": "CONFIRMED",
  "note": "...",
  "createdAt": "Date",
  "updatedAt": "Date"
}

IMPORTANT:

Order items should store a snapshot of:

Product name
Unit price
Selected options
Subtotal

This prevents historical orders from changing when the product price changes later.

40. Favorite Model
{
  "_id": "ObjectId",
  "userId": "ObjectId",
  "businessId": "ObjectId",
  "createdAt": "Date"
}

Unique relationship:

userId + businessId

A customer cannot favorite the same business multiple times.

41. Notification Model
{
  "_id": "ObjectId",
  "userId": "ObjectId",
  "type": "BOOKING_CONFIRMED",
  "title": "Booking confirmed",
  "message": "Your booking has been confirmed.",
  "referenceId": "ObjectId",
  "isRead": false,
  "createdAt": "Date"
}
42. Conversation Model

Conversation is between Customer and Business Owner.

{
  "_id": "ObjectId",
  "customerId": "ObjectId",
  "businessId": "ObjectId",
  "lastMessage": "Quán còn bàn 4 người không?",
  "updatedAt": "Date"
}

One conversation should represent the relationship between one Customer and one Business.

43. Message Model
{
  "_id": "ObjectId",
  "conversationId": "ObjectId",
  "senderId": "ObjectId",
  "senderType": "CUSTOMER",
  "content": "Quán còn bàn 4 người không?",
  "isRead": false,
  "createdAt": "Date"
}

Possible sender types:

CUSTOMER
BUSINESS_OWNER
44. REST API Structure
Authentication
POST /api/auth/register
POST /api/auth/login
GET  /api/auth/me
User
GET /api/users/me
PUT /api/users/me
Business
GET  /api/businesses
GET  /api/businesses/:id
POST /api/businesses
PUT  /api/businesses/:id
Search
GET /api/businesses/search
GET /api/businesses/nearby
Menu
GET /api/businesses/:id/menu
POST /api/menus
PUT /api/menus/:id
DELETE /api/menus/:id
Product
GET    /api/products/:id
POST   /api/products
PUT    /api/products/:id
DELETE /api/products/:id
Favorite
GET    /api/favorites
POST   /api/favorites
DELETE /api/favorites/:businessId
Table
GET    /api/tables
POST   /api/tables
PUT    /api/tables/:id
DELETE /api/tables/:id
Booking
POST /api/bookings
GET  /api/bookings/me
GET  /api/bookings/:id
PUT  /api/bookings/:id
Cart
GET    /api/cart
POST   /api/cart
PUT    /api/cart
DELETE /api/cart/:itemId
Order
POST /api/orders
GET  /api/orders/me
GET  /api/orders/:id
PUT  /api/orders/:id/status
Notifications
GET /api/notifications
PUT /api/notifications/:id/read
Chat
GET  /api/conversations
POST /api/conversations

GET  /api/conversations/:id/messages
POST /api/conversations/:id/messages

PUT /api/messages/:id/read
45. Flutter Architecture

The application should use a layered architecture:

UI / Screens
      ↓
Provider
      ↓
Service
      ↓
REST API
      ↓
Backend

Recommended project structure:

lib/
├── core/
│   ├── constants/
│   ├── theme/
│   ├── routes/
│   └── network/
│
├── models/
│
├── services/
│   ├── auth_service.dart
│   ├── user_service.dart
│   ├── business_service.dart
│   ├── menu_service.dart
│   ├── product_service.dart
│   ├── favorite_service.dart
│   ├── table_service.dart
│   ├── booking_service.dart
│   ├── cart_service.dart
│   ├── order_service.dart
│   ├── notification_service.dart
│   └── chat_service.dart
│
├── providers/
│   ├── auth_provider.dart
│   ├── user_provider.dart
│   ├── business_provider.dart
│   ├── search_provider.dart
│   ├── map_provider.dart
│   ├── favorite_provider.dart
│   ├── menu_provider.dart
│   ├── product_provider.dart
│   ├── table_provider.dart
│   ├── booking_provider.dart
│   ├── cart_provider.dart
│   ├── order_provider.dart
│   ├── notification_provider.dart
│   └── chat_provider.dart
│
├── screens/
│   ├── auth/
│   ├── customer/
│   └── owner/
│
├── widgets/
│
└── main.dart
46. Provider Rules

Provider is the official state management solution.

Do NOT bypass Provider for business logic.

Bad:

Screen
  ↓
HTTP request directly

Preferred:

Screen
  ↓
Provider
  ↓
Service
  ↓
API

Example:

class CartProvider extends ChangeNotifier {
  List<CartItem> items = [];

  Future<void> addToCart(...) async {
    // Call CartService
    // Update local state
    // notifyListeners()
  }
}

UI:

Consumer<CartProvider>(
  builder: (context, cart, child) {
    return Text('${cart.items.length}');
  },
)
47. Shared UI Rules

The application should maintain a consistent visual style.

Recommended:

Clean F&B-focused UI
Primary blue color
Light background
Rounded cards
Moderate shadows
Clear typography
Consistent spacing
Responsive layouts
Minimal unnecessary icons

Do not add icons to every section or every piece of text.

Icons should be used primarily for functional actions:

Search
Location
Favorite
Notification
User
Chat
Map
Cart
48. Customer Navigation

Recommended bottom navigation:

Home
Search
Bookings
Orders
Profile

Other screens such as:

F&B Detail
Product Detail
Cart
Checkout
Chat
Notifications
Map

are accessed through navigation routes.

49. Owner Navigation

Recommended:

Dashboard
Business
Orders
Bookings
Chat
Profile

Owner management screens:

Business
├── Branch
├── Menu
├── Product
└── Table
50. Testing Requirements

The project must include at least:

Unit Test

At least one meaningful business logic test.

Recommended:

Cart total calculation

Example:

Product A = 100,000
Quantity = 2

Product B = 50,000
Quantity = 1

Expected total = 250,000

Other possible unit tests:

Booking validation
Order status validation
Search filter
Authentication validation
51. Widget Test

At least one meaningful Widget Test.

Recommended:

Login Screen

Test:

Render Login Screen.
Enter email.
Enter password.
Tap Login.
Verify loading/state/navigation behavior.

Other possible tests:

Product Detail
Cart
Booking
Chat
52. Release Build

The project must be able to build a release APK.

Command:

flutter build apk --release

The team should verify that:

App builds successfully.
App runs correctly in release mode.
API configuration works in release.
No development-only configuration breaks the application.
53. PRM393 Required Features Checklist

The project must satisfy the following required functions:

Requirement	Implementation
Database/API structure	Node.js REST API + MongoDB
Login screen	Flutter Login
Product list screen	Menu/Product List
Product detail screen	Product Detail
Shopping cart	Cart
Checkout/Billing	Checkout
Notifications	Notification Screen
Map	F&B Map
Messaging/Chat	Customer ↔ Business Owner
State Management	Provider

All ten requirements are covered.

54. Features Explicitly OUT OF SCOPE

Do NOT implement these unless the project scope is officially changed:

AI Chatbot
AI Recommendation
Staff
Review
Rating
Delivery
Voucher
Loyalty
KOL
Social Network
Livestream
Wallet
Inventory
Complex Payment Gateway

The current project should focus on completing the core features instead of expanding the scope.

55. Team Responsibilities
Member 1 — Authentication & Profile
Customer
Splash
Login
Register
Forgot Password
Profile
Owner
Login
Profile
Role navigation
Provider
AuthProvider
UserProvider
Member 2 — Discovery
Customer
Home
Search
Filter
Categories
Map
F&B Detail
Favorite
Provider
BusinessProvider
SearchProvider
MapProvider
FavoriteProvider
Member 3 — Menu & Cart
Customer
Menu
Product List
Product Detail
Cart
Checkout
Owner
Menu Management
Product Management
Provider
MenuProvider
ProductProvider
CartProvider
Member 4 — Booking & Order
Customer
Booking
My Booking
My Order
Order Detail
Order Tracking
Owner
Table Management
Booking Management
Order Management
Provider
TableProvider
BookingProvider
OrderProvider
Member 5 — Communication
Customer
Chat
Notifications
Owner
Chat
Notifications
Dashboard
Provider
ChatProvider
NotificationProvider
56. Testing Responsibilities

Each member should test their own module.

Member 1
→ Login Unit Test
→ Login Widget Test

Member 2
→ Search/Filter Unit Test
→ F&B/Search Widget Test

Member 3
→ Cart Calculation Unit Test
→ Cart/Product Widget Test

Member 4
→ Booking Validation Unit Test
→ Booking Widget Test

Member 5
→ Message Logic Unit Test
→ Chat Widget Test
57. Main Customer Flow

The main demo/business flow is:

Login
   ↓
Home
   ↓
Search / Filter
   ↓
Map / F&B Discovery
   ↓
F&B Detail
   ↓
Menu
   ↓
Product Detail
   ↓
Add to Cart
   ↓
Checkout
   ↓
Booking
   ↓
Order
   ↓
Order Tracking
   ↓
Notification

If the customer needs to contact the business:

F&B Detail
   ↓
Chat
   ↓
Business Owner
58. Main Business Owner Flow
Login
   ↓
Owner Dashboard
   ↓
Business Management
   ↓
Menu / Product Management
   ↓
Table Management
   ↓
Booking Management
   ↓
Order Management
   ↓
Chat with Customers
   ↓
Notifications
59. Important Development Rules
Rule 1 — Do not access MongoDB directly from Flutter

Always:

Flutter → REST API → Backend → MongoDB
Rule 2 — Use Provider for application state

Do not put complex business logic directly inside Widgets.

Rule 3 — Separate UI and API logic

Screens should focus on UI.

API requests belong in Services.

State belongs in Providers.

Rule 4 — Reuse Models

Models should represent API/domain data consistently.

Examples:

User
Business
Branch
Menu
Product
Table
Booking
Cart
Order
Favorite
Notification
Conversation
Message
Rule 5 — Respect Role Permissions

Customer must not access Owner management functions.

Owner must only manage their own business data.

Examples:

CUSTOMER
→ Create Booking
→ Create Order
→ Chat

BUSINESS_OWNER
→ Manage Product
→ Manage Table
→ Manage Booking
→ Manage Order
→ Chat
Rule 6 — Do not expand scope without agreement

The current MVP intentionally excludes advanced features.

Focus on:

Authentication + Discovery + Menu/Product + Cart + Checkout + Booking + Order + Notification + Map + Chat

60. Final Project Definition

FConnect PRM393 is a Flutter-based F&B mobile application supporting two roles: Customer and Business Owner.

Customers can discover F&B locations, search and filter businesses, view locations on a map, view menus and products, favorite businesses, book tables, add products to a shopping cart, checkout, track orders, receive notifications, and communicate directly with Business Owners.

Business Owners use the same Flutter application with role-based interfaces to manage their business, menus, products, tables, bookings, orders, notifications, and customer conversations.

The application uses Provider for state management and communicates with a Node.js REST API, which handles authentication, business logic, and MongoDB data access.

The PRM393 implementation focuses on a clear, complete mobile application flow and does not include AI, Staff, Reviews, Ratings, Delivery, Loyalty, or other advanced features.