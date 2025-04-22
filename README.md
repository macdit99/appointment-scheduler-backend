# Appointment Scheduler Backend

A FastAPI backend for a small business appointment scheduling system using Supabase (PostgreSQL) as the database.

## Features

- Complete database schema for appointment scheduling
- RESTful API for managing businesses, services, clients, and appointments
- Integration with Supabase for PostgreSQL database and authentication
- Comprehensive data validation and error handling

## Database Schema

The database is designed with the following tables:

- **businesses**: Store business information (name, address, contact info)
- **business_hours**: Business operating hours for each day of the week
- **service_categories**: Categories for organizing services
- **services**: Services offered by the business (name, duration, price, description)
- **clients**: Client information (name, contact info, notes)
- **staff**: Staff members who provide services
- **staff_services**: Junction table for staff-service relationships
- **staff_schedules**: Staff working hours
- **appointments**: Appointment bookings (date, time, service, client, status)
- **appointment_reminders**: Reminders for upcoming appointments

For the complete schema, see [database-design.md](database-design.md) and [schema.sql](schema.sql).

## Setup

### Prerequisites

- Python 3.12 or higher
- Supabase account

### Installation

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/appointment-scheduler-backend.git
   cd appointment-scheduler-backend
   ```

2. Create a virtual environment and install dependencies:
   ```
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. Set up environment variables:
   ```
   export SUPABASE_URL=your_supabase_url
   export SUPABASE_KEY=your_supabase_key
   ```
   On Windows:
   ```
   set SUPABASE_URL=your_supabase_url
   set SUPABASE_KEY=your_supabase_key
   ```

4. Set up the database:
   - Create a new Supabase project
   - Execute the SQL in `schema.sql` in the Supabase SQL Editor

5. Run the application:
   ```
   # Using the run.py script (recommended)
   python run.py

   # Or directly with uvicorn
   uvicorn main:app --reload
   ```

6. Access the API documentation at http://localhost:8000/docs

## API Endpoints

### Businesses
- `POST /businesses/`: Create a new business
- `GET /businesses/{business_id}`: Get business details

### Services
- `POST /services/`: Create a new service
- `GET /services/`: List all services for the current business

### Clients
- `POST /clients/`: Create a new client
- `GET /clients/`: List all clients for the current business

### Appointments
- `POST /appointments/`: Create a new appointment
- `GET /appointments/`: List all appointments for the current business
- `GET /appointments/{appointment_id}`: Get appointment details
- `PUT /appointments/{appointment_id}/status`: Update appointment status

## Authentication

The application uses Supabase authentication. In a production environment, you would:

1. Implement proper JWT token validation
2. Use Row Level Security (RLS) in Supabase to restrict data access
3. Extract the business_id from the authenticated user's JWT token

## Future Enhancements

- Staff management endpoints
- Business hours management
- Service category management
- Advanced appointment filtering and searching
- Payment processing integration
- Email and SMS notifications

## License

[MIT](LICENSE)
