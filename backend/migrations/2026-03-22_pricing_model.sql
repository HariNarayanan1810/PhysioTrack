USE physiotrack;

ALTER TABLE doctors
  ADD COLUMN clinic_fee DECIMAL(10,2) NOT NULL DEFAULT 0;

ALTER TABLE doctors
  ADD COLUMN home_visit_base_fee DECIMAL(10,2) NOT NULL DEFAULT 0;

ALTER TABLE doctors
  ADD COLUMN per_km_charge DECIMAL(10,2) NULL;

ALTER TABLE appointments
  ADD COLUMN distance_km DECIMAL(10,2) NULL;

ALTER TABLE appointments
  ADD COLUMN session_fee DECIMAL(10,2) NULL;

ALTER TABLE appointments
  ADD COLUMN is_special_session TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE appointments
  ADD COLUMN special_fee_amount DECIMAL(10,2) NULL;

ALTER TABLE appointments
  ADD COLUMN special_fee_reason VARCHAR(255) NULL;

UPDATE doctors d
LEFT JOIN doctor_verification_requests vr
  ON vr.request_id = (
    SELECT v2.request_id
    FROM doctor_verification_requests v2
    WHERE v2.doctor_id = d.doctor_id
      AND v2.status = 'APPROVED'
    ORDER BY v2.request_id DESC
    LIMIT 1
  )
SET d.clinic_fee = COALESCE(NULLIF(d.clinic_fee, 0), vr.consultation_fee, 0),
    d.home_visit_base_fee = COALESCE(
      NULLIF(d.home_visit_base_fee, 0),
      NULLIF(d.clinic_fee, 0),
      vr.consultation_fee,
      0
    );
