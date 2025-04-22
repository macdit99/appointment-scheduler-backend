-- Small Business Appointment Scheduler Database Schema
-- For Supabase (PostgreSQL)

-- Enable UUID extension if not already enabled
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Businesses table
CREATE TABLE businesses (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    address TEXT,
    phone VARCHAR(20),
    email VARCHAR(100),
    website VARCHAR(255),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_businesses_name ON businesses(name);

-- Business hours table
CREATE TABLE business_hours (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0 = Sunday, 6 = Saturday
    open_time TIME NOT NULL,
    close_time TIME NOT NULL,
    is_closed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (business_id, day_of_week)
);

CREATE INDEX idx_business_hours_business_id ON business_hours(business_id);

-- Service categories table
CREATE TABLE service_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (business_id, name)
);

CREATE INDEX idx_service_categories_business_id ON service_categories(business_id);

-- Services table
CREATE TABLE services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    category_id UUID REFERENCES service_categories(id) ON DELETE SET NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    duration INTEGER NOT NULL, -- in minutes
    price DECIMAL(10, 2) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (business_id, name)
);

CREATE INDEX idx_services_business_id ON services(business_id);
CREATE INDEX idx_services_category_id ON services(category_id);

-- Clients table
CREATE TABLE clients (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_clients_business_id ON clients(business_id);
CREATE INDEX idx_clients_email ON clients(email);
CREATE INDEX idx_clients_name ON clients(last_name, first_name);

-- Staff table
CREATE TABLE staff (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone VARCHAR(20),
    position VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_staff_business_id ON staff(business_id);

-- Staff services junction table
CREATE TABLE staff_services (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (staff_id, service_id)
);

CREATE INDEX idx_staff_services_staff_id ON staff_services(staff_id);
CREATE INDEX idx_staff_services_service_id ON staff_services(service_id);

-- Staff schedules table
CREATE TABLE staff_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    staff_id UUID NOT NULL REFERENCES staff(id) ON DELETE CASCADE,
    day_of_week SMALLINT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6),
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    is_working BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (staff_id, day_of_week)
);

CREATE INDEX idx_staff_schedules_staff_id ON staff_schedules(staff_id);

-- Appointments table
CREATE TABLE appointments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES clients(id) ON DELETE CASCADE,
    service_id UUID NOT NULL REFERENCES services(id) ON DELETE RESTRICT,
    staff_id UUID REFERENCES staff(id) ON DELETE SET NULL,
    start_time TIMESTAMP WITH TIME ZONE NOT NULL,
    end_time TIMESTAMP WITH TIME ZONE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'scheduled' 
        CHECK (status IN ('scheduled', 'confirmed', 'completed', 'cancelled', 'no-show')),
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_appointments_business_id ON appointments(business_id);
CREATE INDEX idx_appointments_client_id ON appointments(client_id);
CREATE INDEX idx_appointments_service_id ON appointments(service_id);
CREATE INDEX idx_appointments_staff_id ON appointments(staff_id);
CREATE INDEX idx_appointments_start_time ON appointments(start_time);
CREATE INDEX idx_appointments_status ON appointments(status);

-- Appointment reminders table
CREATE TABLE appointment_reminders (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    appointment_id UUID NOT NULL REFERENCES appointments(id) ON DELETE CASCADE,
    reminder_type VARCHAR(20) NOT NULL CHECK (reminder_type IN ('email', 'sms')),
    scheduled_time TIMESTAMP WITH TIME ZONE NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE,
    status VARCHAR(20) NOT NULL DEFAULT 'pending' 
        CHECK (status IN ('pending', 'sent', 'failed')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_appointment_reminders_appointment_id ON appointment_reminders(appointment_id);
CREATE INDEX idx_appointment_reminders_scheduled_time ON appointment_reminders(scheduled_time);

-- Row Level Security (RLS) Policies
-- Enable RLS on all tables
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE business_hours ENABLE ROW LEVEL SECURITY;
ALTER TABLE service_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE services ENABLE ROW LEVEL SECURITY;
ALTER TABLE clients ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_services ENABLE ROW LEVEL SECURITY;
ALTER TABLE staff_schedules ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointments ENABLE ROW LEVEL SECURITY;
ALTER TABLE appointment_reminders ENABLE ROW LEVEL SECURITY;

-- Example RLS policy for businesses (to be customized based on your auth setup)
CREATE POLICY business_policy ON businesses
    USING (auth.uid() IN (
        SELECT user_id FROM business_users WHERE business_id = id
    ));

-- Triggers for updated_at timestamps
CREATE OR REPLACE FUNCTION update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for all tables with updated_at column
CREATE TRIGGER update_businesses_modtime
    BEFORE UPDATE ON businesses
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_business_hours_modtime
    BEFORE UPDATE ON business_hours
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_service_categories_modtime
    BEFORE UPDATE ON service_categories
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_services_modtime
    BEFORE UPDATE ON services
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_clients_modtime
    BEFORE UPDATE ON clients
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_staff_modtime
    BEFORE UPDATE ON staff
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_staff_schedules_modtime
    BEFORE UPDATE ON staff_schedules
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_appointments_modtime
    BEFORE UPDATE ON appointments
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

CREATE TRIGGER update_appointment_reminders_modtime
    BEFORE UPDATE ON appointment_reminders
    FOR EACH ROW EXECUTE FUNCTION update_modified_column();

-- Note: You'll need to create a business_users table to link Supabase Auth users to businesses
-- This is just a placeholder example - implement according to your auth strategy
CREATE TABLE business_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    role VARCHAR(20) NOT NULL DEFAULT 'staff' 
        CHECK (role IN ('owner', 'admin', 'staff')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (business_id, user_id)
);

CREATE INDEX idx_business_users_business_id ON business_users(business_id);
CREATE INDEX idx_business_users_user_id ON business_users(user_id);
ALTER TABLE business_users ENABLE ROW LEVEL SECURITY;