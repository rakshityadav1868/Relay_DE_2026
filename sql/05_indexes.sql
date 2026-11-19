SET search_path TO uc;

CREATE INDEX idx_bookings_pro_id ON bookings (pro_id);
CREATE INDEX idx_bookings_customer_id ON bookings (customer_id);
CREATE INDEX idx_bookings_status ON bookings (status);
CREATE INDEX idx_bookings_scheduled_start ON bookings (scheduled_start);
CREATE INDEX idx_bookings_booked_at ON bookings (booked_at);
CREATE INDEX idx_bookings_city_id ON bookings (city_id);
CREATE INDEX idx_professionals_city_id ON professionals (city_id);
CREATE INDEX idx_pro_availability_work_date ON pro_availability (work_date);
CREATE INDEX idx_pro_skills_category_id ON pro_skills (category_id);
CREATE INDEX idx_reviews_created_at ON reviews (created_at);
CREATE INDEX idx_reschedules_created_at ON reschedules (created_at);
CREATE INDEX idx_payouts_week_start ON payouts (week_start);
