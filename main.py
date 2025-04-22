from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
from typing import List, Optional
from datetime import datetime, time
import os
from supabase import create_client, Client

# Initialize Supabase client
# supabase_url = os.environ.get("SUPABASE_URL")
supabase_url = os.getenv("SUPABASE_URL")
supabase_key = os.getenv("SUPABASE_KEY")

#supabase_key = os.environ.get("SUPABASE_KEY")

# Check if environment variables are set
if not supabase_url or not supabase_key:
    raise ValueError("SUPABASE_URL and SUPABASE_KEY environment variables must be set")

supabase: Client = create_client(supabase_url, supabase_key)

app = FastAPI(title="Appointment Scheduler API")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Specify your frontend domain in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Pydantic models for request/response validation
class BusinessBase(BaseModel):
    name: str
    address: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[str] = None
    website: Optional[str] = None

class BusinessCreate(BusinessBase):
    pass

class Business(BusinessBase):
    id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class BusinessHourBase(BaseModel):
    day_of_week: int = Field(..., ge=0, le=6)
    open_time: time
    close_time: time
    is_closed: bool = False

class BusinessHourCreate(BusinessHourBase):
    pass

class BusinessHour(BusinessHourBase):
    id: str
    business_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class ServiceBase(BaseModel):
    name: str
    description: Optional[str] = None
    duration: int  # in minutes
    price: float
    is_active: bool = True
    category_id: Optional[str] = None

class ServiceCreate(ServiceBase):
    pass

class Service(ServiceBase):
    id: str
    business_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class ClientBase(BaseModel):
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    notes: Optional[str] = None

class ClientCreate(ClientBase):
    pass

class Client(ClientBase):
    id: str
    business_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

class AppointmentBase(BaseModel):
    service_id: str
    client_id: str
    staff_id: Optional[str] = None
    start_time: datetime
    end_time: datetime
    status: str = "scheduled"
    notes: Optional[str] = None

class AppointmentCreate(AppointmentBase):
    pass

class Appointment(AppointmentBase):
    id: str
    business_id: str
    created_at: datetime
    updated_at: datetime

    class Config:
        orm_mode = True

# Helper function to get current user's business_id
async def get_business_id():
    # In a real implementation, this would extract the business_id from the JWT token
    # For now, we'll use a placeholder
    return "00000000-0000-0000-0000-000000000000"

# API Routes
@app.get("/")
def read_root():
    return {"message": "Welcome to the Appointment Scheduler API"}

# Business endpoints
@app.post("/businesses/", response_model=Business)
async def create_business(business: BusinessCreate):
    try:
        result = supabase.table("businesses").insert(business.dict()).execute()
        return result.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/businesses/{business_id}", response_model=Business)
async def get_business(business_id: str):
    try:
        result = supabase.table("businesses").select("*").eq("id", business_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="Business not found")
        return result.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Service endpoints
@app.post("/services/", response_model=Service)
async def create_service(service: ServiceCreate, business_id: str = Depends(get_business_id)):
    try:
        service_data = service.dict()
        service_data["business_id"] = business_id
        result = supabase.table("services").insert(service_data).execute()
        return result.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/services/", response_model=List[Service])
async def list_services(business_id: str = Depends(get_business_id)):
    try:
        result = supabase.table("services").select("*").eq("business_id", business_id).execute()
        return result.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Client endpoints
@app.post("/clients/", response_model=Client)
async def create_client(client: ClientCreate, business_id: str = Depends(get_business_id)):
    try:
        client_data = client.dict()
        client_data["business_id"] = business_id
        result = supabase.table("clients").insert(client_data).execute()
        return result.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/clients/", response_model=List[Client])
async def list_clients(business_id: str = Depends(get_business_id)):
    try:
        result = supabase.table("clients").select("*").eq("business_id", business_id).execute()
        return result.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Appointment endpoints
@app.post("/appointments/", response_model=Appointment)
async def create_appointment(appointment: AppointmentCreate, business_id: str = Depends(get_business_id)):
    try:
        # Validate that the service exists
        service_result = supabase.table("services").select("*").eq("id", appointment.service_id).execute()
        if not service_result.data:
            raise HTTPException(status_code=404, detail="Service not found")

        # Validate that the client exists
        client_result = supabase.table("clients").select("*").eq("id", appointment.client_id).execute()
        if not client_result.data:
            raise HTTPException(status_code=404, detail="Client not found")

        # If staff_id is provided, validate that the staff exists
        if appointment.staff_id:
            staff_result = supabase.table("staff").select("*").eq("id", appointment.staff_id).execute()
            if not staff_result.data:
                raise HTTPException(status_code=404, detail="Staff not found")

        appointment_data = appointment.dict()
        appointment_data["business_id"] = business_id
        result = supabase.table("appointments").insert(appointment_data).execute()

        # Create a reminder for the appointment
        reminder_data = {
            "appointment_id": result.data[0]["id"],
            "reminder_type": "email",
            "scheduled_time": appointment.start_time.isoformat(),
            "status": "pending"
        }
        supabase.table("appointment_reminders").insert(reminder_data).execute()

        return result.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/appointments/", response_model=List[Appointment])
async def list_appointments(business_id: str = Depends(get_business_id)):
    try:
        result = supabase.table("appointments").select("*").eq("business_id", business_id).execute()
        return result.data
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/appointments/{appointment_id}", response_model=Appointment)
async def get_appointment(appointment_id: str):
    try:
        result = supabase.table("appointments").select("*").eq("id", appointment_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="Appointment not found")
        return result.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.put("/appointments/{appointment_id}/status", response_model=Appointment)
async def update_appointment_status(appointment_id: str, status: str):
    if status not in ["scheduled", "confirmed", "completed", "cancelled", "no-show"]:
        raise HTTPException(status_code=400, detail="Invalid status value")

    try:
        result = supabase.table("appointments").update({"status": status}).eq("id", appointment_id).execute()
        if not result.data:
            raise HTTPException(status_code=404, detail="Appointment not found")
        return result.data[0]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
