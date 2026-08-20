CREATE DATABASE IF NOT EXISTS physiotrack;
USE physiotrack;

CREATE TABLE IF NOT EXISTS doctors (
  doctor_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(120),
  phone VARCHAR(20),
  age INT NOT NULL,
  qualification VARCHAR(20) NOT NULL,
  years_of_experience INT NOT NULL,
  clinic_name VARCHAR(120) NOT NULL,
  rating DECIMAL(2,1) NOT NULL,
  profile_image_url VARCHAR(255) NOT NULL,
  latitude DECIMAL(10,6) NOT NULL,
  longitude DECIMAL(10,6) NOT NULL,
  clinic_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
  home_visit_base_fee DECIMAL(10,2) NOT NULL DEFAULT 0,
  per_km_charge DECIMAL(10,2) NULL,
  is_verified TINYINT(1) NOT NULL DEFAULT 0,
  approval_status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING',
  verification_status VARCHAR(20) NOT NULL DEFAULT 'not_applied',
  is_removed TINYINT(1) NOT NULL DEFAULT 0,
  removed_reason TEXT,
  removed_at TIMESTAMP NULL
);

SET @email_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'email'
);
SET @sql_email := IF(
  @email_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN email VARCHAR(120)',
  'SELECT 1'
);
PREPARE stmt_email FROM @sql_email;
EXECUTE stmt_email;
DEALLOCATE PREPARE stmt_email;

SET @phone_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'phone'
);
SET @sql_phone := IF(
  @phone_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN phone VARCHAR(20)',
  'SELECT 1'
);
PREPARE stmt_phone FROM @sql_phone;
EXECUTE stmt_phone;
DEALLOCATE PREPARE stmt_phone;

SET @is_removed_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'is_removed'
);
SET @sql_is_removed := IF(
  @is_removed_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN is_removed TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt_is_removed FROM @sql_is_removed;
EXECUTE stmt_is_removed;
DEALLOCATE PREPARE stmt_is_removed;

SET @removed_reason_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'removed_reason'
);
SET @sql_removed_reason := IF(
  @removed_reason_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN removed_reason TEXT',
  'SELECT 1'
);
PREPARE stmt_removed_reason FROM @sql_removed_reason;
EXECUTE stmt_removed_reason;
DEALLOCATE PREPARE stmt_removed_reason;

SET @removed_at_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'removed_at'
);
SET @sql_removed_at := IF(
  @removed_at_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN removed_at TIMESTAMP NULL',
  'SELECT 1'
);
PREPARE stmt_removed_at FROM @sql_removed_at;
EXECUTE stmt_removed_at;
DEALLOCATE PREPARE stmt_removed_at;

SET @is_verified_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'is_verified'
);
SET @sql_is_verified := IF(
  @is_verified_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN is_verified TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt_is_verified FROM @sql_is_verified;
EXECUTE stmt_is_verified;
DEALLOCATE PREPARE stmt_is_verified;


SET @approval_status_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'approval_status'
);
SET @sql_approval_status := IF(
  @approval_status_col_exists = 0,
  "ALTER TABLE doctors ADD COLUMN approval_status ENUM('PENDING','APPROVED','REJECTED') NOT NULL DEFAULT 'PENDING'",
  'SELECT 1'
);
PREPARE stmt_approval_status FROM @sql_approval_status;
EXECUTE stmt_approval_status;
DEALLOCATE PREPARE stmt_approval_status;

SET @verification_status_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'verification_status'
);
SET @sql_verification_status := IF(
  @verification_status_col_exists = 0,
  "ALTER TABLE doctors ADD COLUMN verification_status VARCHAR(20) NOT NULL DEFAULT 'not_applied'",
  'SELECT 1'
);
PREPARE stmt_verification_status FROM @sql_verification_status;
EXECUTE stmt_verification_status;
DEALLOCATE PREPARE stmt_verification_status;

UPDATE doctors
SET verification_status = CASE
  WHEN UPPER(approval_status) = 'APPROVED' THEN 'approved'
  WHEN UPPER(approval_status) = 'REJECTED' THEN 'rejected'
  WHEN UPPER(approval_status) = 'PENDING' THEN 'pending'
  ELSE 'not_applied'
END
WHERE verification_status IS NULL OR verification_status = '' OR verification_status = 'not_applied';

SET @clinic_fee_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'clinic_fee'
);
SET @sql_clinic_fee := IF(
  @clinic_fee_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN clinic_fee DECIMAL(10,2) NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt_clinic_fee FROM @sql_clinic_fee;
EXECUTE stmt_clinic_fee;
DEALLOCATE PREPARE stmt_clinic_fee;

SET @home_visit_base_fee_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'home_visit_base_fee'
);
SET @sql_home_visit_base_fee := IF(
  @home_visit_base_fee_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN home_visit_base_fee DECIMAL(10,2) NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt_home_visit_base_fee FROM @sql_home_visit_base_fee;
EXECUTE stmt_home_visit_base_fee;
DEALLOCATE PREPARE stmt_home_visit_base_fee;

SET @per_km_charge_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'per_km_charge'
);
SET @sql_per_km_charge := IF(
  @per_km_charge_col_exists = 0,
  'ALTER TABLE doctors ADD COLUMN per_km_charge DECIMAL(10,2) NULL',
  'SELECT 1'
);
PREPARE stmt_per_km_charge FROM @sql_per_km_charge;
EXECUTE stmt_per_km_charge;
DEALLOCATE PREPARE stmt_per_km_charge;

CREATE TABLE IF NOT EXISTS patients (
  patient_id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NULL,
  name VARCHAR(100) NOT NULL,
  age INT NOT NULL,
  email VARCHAR(120) NOT NULL,
  phone VARCHAR(20) NOT NULL,
  address TEXT NOT NULL,
  dob DATE NULL,
  profile_image VARCHAR(255) NULL,
  state VARCHAR(100) NULL,
  city VARCHAR(100) NULL,
  latitude DOUBLE NULL,
  longitude DOUBLE NULL,
  is_removed TINYINT(1) NOT NULL DEFAULT 0,
  removed_reason TEXT,
  removed_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  firebase_uid VARCHAR(128) UNIQUE NOT NULL,
  email VARCHAR(120) NOT NULL,
  role ENUM('ADMIN','DOCTOR','PATIENT') NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS user_device_tokens (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  role VARCHAR(20) NOT NULL,
  fcm_token VARCHAR(255) NOT NULL,
  platform VARCHAR(20) NOT NULL DEFAULT 'unknown',
  updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_user_device_tokens_token (fcm_token),
  KEY idx_user_device_tokens_user (user_id),
  CONSTRAINT fk_user_device_tokens_user
    FOREIGN KEY (user_id) REFERENCES users(id)
    ON DELETE CASCADE
);

SET @doctor_user_id_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND column_name = 'user_id'
);
SET @sql_doctor_user_id := IF(
  @doctor_user_id_exists = 0,
  'ALTER TABLE doctors ADD COLUMN user_id INT NULL',
  'SELECT 1'
);
PREPARE stmt_doctor_user_id FROM @sql_doctor_user_id;
EXECUTE stmt_doctor_user_id;
DEALLOCATE PREPARE stmt_doctor_user_id;

SET @patient_user_id_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'user_id'
);
SET @sql_patient_user_id := IF(
  @patient_user_id_exists = 0,
  'ALTER TABLE patients ADD COLUMN user_id INT NULL',
  'SELECT 1'
);
PREPARE stmt_patient_user_id FROM @sql_patient_user_id;
EXECUTE stmt_patient_user_id;
DEALLOCATE PREPARE stmt_patient_user_id;

SET @patient_dob_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'dob'
);
SET @sql_patient_dob := IF(
  @patient_dob_exists = 0,
  'ALTER TABLE patients ADD COLUMN dob DATE NULL',
  'SELECT 1'
);
PREPARE stmt_patient_dob FROM @sql_patient_dob;
EXECUTE stmt_patient_dob;
DEALLOCATE PREPARE stmt_patient_dob;

SET @patient_profile_image_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'profile_image'
);
SET @sql_patient_profile_image := IF(
  @patient_profile_image_exists = 0,
  'ALTER TABLE patients ADD COLUMN profile_image VARCHAR(255) NULL',
  'SELECT 1'
);
PREPARE stmt_patient_profile_image FROM @sql_patient_profile_image;
EXECUTE stmt_patient_profile_image;
DEALLOCATE PREPARE stmt_patient_profile_image;

SET @patient_state_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'state'
);
SET @sql_patient_state := IF(
  @patient_state_exists = 0,
  'ALTER TABLE patients ADD COLUMN state VARCHAR(100) NULL',
  'SELECT 1'
);
PREPARE stmt_patient_state FROM @sql_patient_state;
EXECUTE stmt_patient_state;
DEALLOCATE PREPARE stmt_patient_state;

SET @patient_city_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'city'
);
SET @sql_patient_city := IF(
  @patient_city_exists = 0,
  'ALTER TABLE patients ADD COLUMN city VARCHAR(100) NULL',
  'SELECT 1'
);
PREPARE stmt_patient_city FROM @sql_patient_city;
EXECUTE stmt_patient_city;
DEALLOCATE PREPARE stmt_patient_city;

SET @patient_lat_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'latitude'
);
SET @sql_patient_lat := IF(
  @patient_lat_exists = 0,
  'ALTER TABLE patients ADD COLUMN latitude DOUBLE NULL',
  'SELECT 1'
);
PREPARE stmt_patient_lat FROM @sql_patient_lat;
EXECUTE stmt_patient_lat;
DEALLOCATE PREPARE stmt_patient_lat;

SET @patient_lng_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'longitude'
);
SET @sql_patient_lng := IF(
  @patient_lng_exists = 0,
  'ALTER TABLE patients ADD COLUMN longitude DOUBLE NULL',
  'SELECT 1'
);
PREPARE stmt_patient_lng FROM @sql_patient_lng;
EXECUTE stmt_patient_lng;
DEALLOCATE PREPARE stmt_patient_lng;

SET @patient_is_removed_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'is_removed'
);
SET @sql_patient_is_removed := IF(
  @patient_is_removed_exists = 0,
  'ALTER TABLE patients ADD COLUMN is_removed TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt_patient_is_removed FROM @sql_patient_is_removed;
EXECUTE stmt_patient_is_removed;
DEALLOCATE PREPARE stmt_patient_is_removed;

SET @patient_removed_reason_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'removed_reason'
);
SET @sql_patient_removed_reason := IF(
  @patient_removed_reason_exists = 0,
  'ALTER TABLE patients ADD COLUMN removed_reason TEXT',
  'SELECT 1'
);
PREPARE stmt_patient_removed_reason FROM @sql_patient_removed_reason;
EXECUTE stmt_patient_removed_reason;
DEALLOCATE PREPARE stmt_patient_removed_reason;

SET @patient_removed_at_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND column_name = 'removed_at'
);
SET @sql_patient_removed_at := IF(
  @patient_removed_at_exists = 0,
  'ALTER TABLE patients ADD COLUMN removed_at TIMESTAMP NULL',
  'SELECT 1'
);
PREPARE stmt_patient_removed_at FROM @sql_patient_removed_at;
EXECUTE stmt_patient_removed_at;
DEALLOCATE PREPARE stmt_patient_removed_at;

SET @fk_doctors_user_exists := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'doctors'
    AND constraint_name = 'fk_doctors_user'
);
SET @sql_fk_doctors_user := IF(
  @fk_doctors_user_exists = 0,
  'ALTER TABLE doctors ADD CONSTRAINT fk_doctors_user FOREIGN KEY (user_id) REFERENCES users(id)',
  'SELECT 1'
);
PREPARE stmt_fk_doctors_user FROM @sql_fk_doctors_user;
EXECUTE stmt_fk_doctors_user;
DEALLOCATE PREPARE stmt_fk_doctors_user;

SET @fk_patients_user_exists := (
  SELECT COUNT(*)
  FROM information_schema.table_constraints
  WHERE table_schema = DATABASE()
    AND table_name = 'patients'
    AND constraint_name = 'fk_patients_user'
);
SET @sql_fk_patients_user := IF(
  @fk_patients_user_exists = 0,
  'ALTER TABLE patients ADD CONSTRAINT fk_patients_user FOREIGN KEY (user_id) REFERENCES users(id)',
  'SELECT 1'
);
PREPARE stmt_fk_patients_user FROM @sql_fk_patients_user;
EXECUTE stmt_fk_patients_user;
DEALLOCATE PREPARE stmt_fk_patients_user;

CREATE TABLE IF NOT EXISTS appointments (
  appointment_id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  patient_id INT NOT NULL,
  appointment_date VARCHAR(20) NOT NULL,
  appointment_time VARCHAR(20) NOT NULL,
  status ENUM('REQUESTED','APPROVED','IN_PROGRESS','COMPLETED','CANCELLED','REJECTED') NOT NULL,
  visit_type ENUM('CLINIC','HOME') NOT NULL,
  preferred_payment_method ENUM('cash','online','credit','debit') NOT NULL DEFAULT 'cash',
  distance_km DECIMAL(10,2) NULL,
  session_fee DECIMAL(10,2) NULL,
  is_special_session TINYINT(1) NOT NULL DEFAULT 0,
  special_fee_amount DECIMAL(10,2) NULL,
  special_fee_reason VARCHAR(255) NULL,
  actual_start_time DATETIME NULL,
  actual_end_time DATETIME NULL,
  live_tracking_enabled TINYINT(1) NOT NULL DEFAULT 0,
  doctor_live_latitude DECIMAL(10,6) NULL,
  doctor_live_longitude DECIMAL(10,6) NULL,
  current_eta_minutes INT NULL,
  last_location_updated_at DATETIME NULL,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

SET @distance_km_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'appointments'
    AND column_name = 'distance_km'
);
SET @sql_distance_km := IF(
  @distance_km_col_exists = 0,
  'ALTER TABLE appointments ADD COLUMN distance_km DECIMAL(10,2) NULL',
  'SELECT 1'
);
PREPARE stmt_distance_km FROM @sql_distance_km;
EXECUTE stmt_distance_km;
DEALLOCATE PREPARE stmt_distance_km;

SET @session_fee_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'appointments'
    AND column_name = 'session_fee'
);
SET @sql_session_fee := IF(
  @session_fee_col_exists = 0,
  'ALTER TABLE appointments ADD COLUMN session_fee DECIMAL(10,2) NULL',
  'SELECT 1'
);
PREPARE stmt_session_fee FROM @sql_session_fee;
EXECUTE stmt_session_fee;
DEALLOCATE PREPARE stmt_session_fee;

SET @is_special_session_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'appointments'
    AND column_name = 'is_special_session'
);
SET @sql_is_special_session := IF(
  @is_special_session_col_exists = 0,
  'ALTER TABLE appointments ADD COLUMN is_special_session TINYINT(1) NOT NULL DEFAULT 0',
  'SELECT 1'
);
PREPARE stmt_is_special_session FROM @sql_is_special_session;
EXECUTE stmt_is_special_session;
DEALLOCATE PREPARE stmt_is_special_session;

SET @special_fee_amount_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'appointments'
    AND column_name = 'special_fee_amount'
);
SET @sql_special_fee_amount := IF(
  @special_fee_amount_col_exists = 0,
  'ALTER TABLE appointments ADD COLUMN special_fee_amount DECIMAL(10,2) NULL',
  'SELECT 1'
);
PREPARE stmt_special_fee_amount FROM @sql_special_fee_amount;
EXECUTE stmt_special_fee_amount;
DEALLOCATE PREPARE stmt_special_fee_amount;

SET @special_fee_reason_col_exists := (
  SELECT COUNT(*)
  FROM information_schema.columns
  WHERE table_schema = DATABASE()
    AND table_name = 'appointments'
    AND column_name = 'special_fee_reason'
);
SET @sql_special_fee_reason := IF(
  @special_fee_reason_col_exists = 0,
  'ALTER TABLE appointments ADD COLUMN special_fee_reason VARCHAR(255) NULL',
  'SELECT 1'
);
PREPARE stmt_special_fee_reason FROM @sql_special_fee_reason;
EXECUTE stmt_special_fee_reason;
DEALLOCATE PREPARE stmt_special_fee_reason;


ALTER TABLE appointments
  MODIFY COLUMN status ENUM('REQUESTED','APPROVED','IN_PROGRESS','COMPLETED','CANCELLED','REJECTED') NOT NULL,
  ADD COLUMN IF NOT EXISTS actual_start_time DATETIME NULL,
  ADD COLUMN IF NOT EXISTS actual_end_time DATETIME NULL,
  ADD COLUMN IF NOT EXISTS live_tracking_enabled TINYINT(1) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS doctor_live_latitude DECIMAL(10,6) NULL,
  ADD COLUMN IF NOT EXISTS doctor_live_longitude DECIMAL(10,6) NULL,
  ADD COLUMN IF NOT EXISTS current_eta_minutes INT NULL,
  ADD COLUMN IF NOT EXISTS last_location_updated_at DATETIME NULL,
  MODIFY COLUMN preferred_payment_method ENUM('cash','online','credit','debit') NOT NULL DEFAULT 'cash';

CREATE TABLE IF NOT EXISTS payments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  appointment_id INT NOT NULL,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  amount DECIMAL(10,2) NOT NULL,
  payment_method ENUM('cash','online','credit','debit') NOT NULL DEFAULT 'cash',
  payment_status ENUM('pending','paid','partial','failed') NOT NULL DEFAULT 'pending',
  razorpay_order_id VARCHAR(100) NULL,
  razorpay_payment_id VARCHAR(100) NULL,
  payment_date DATETIME NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (appointment_id) REFERENCES appointments(appointment_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  INDEX idx_payments_doctor_status (doctor_id, payment_status),
  INDEX idx_payments_patient_status (patient_id, payment_status)
);

ALTER TABLE payments
  MODIFY COLUMN payment_method ENUM('cash','online','credit','debit','razorpay') NOT NULL DEFAULT 'cash';

ALTER TABLE payments
  MODIFY COLUMN payment_status ENUM('pending','paid','partial','failed') NOT NULL DEFAULT 'pending';

ALTER TABLE payments
  ADD COLUMN IF NOT EXISTS razorpay_order_id VARCHAR(100) NULL,
  ADD COLUMN IF NOT EXISTS razorpay_payment_id VARCHAR(100) NULL;


CREATE TABLE IF NOT EXISTS exercises (
  exercise_id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  exercise_name VARCHAR(150) NOT NULL,
  status ENUM('PENDING','DONE') NOT NULL DEFAULT 'PENDING',
  notes VARCHAR(255) DEFAULT '',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

CREATE TABLE IF NOT EXISTS doctor_verification_requests (
  request_id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  full_name VARCHAR(120) NOT NULL,
  date_of_birth DATE NOT NULL,
  qualification VARCHAR(120) NOT NULL,
  university_name VARCHAR(150) NOT NULL,
  year_of_graduation INT NOT NULL,
  years_of_experience INT NOT NULL,
  specialization VARCHAR(100) NOT NULL,
  license_number VARCHAR(100) NOT NULL,
  license_issuing_authority VARCHAR(150) NOT NULL,
  license_expiry_date DATE NOT NULL,
  clinic_name VARCHAR(150) NOT NULL,
  clinic_address VARCHAR(255) NOT NULL,
  city VARCHAR(100) NOT NULL,
  area VARCHAR(100) NOT NULL,
  pincode VARCHAR(20) NOT NULL,
  clinic_contact_number VARCHAR(20) NOT NULL,
  consultation_fee DECIMAL(10,2) NOT NULL,
  home_visit_available TINYINT(1) DEFAULT 0,
  latitude DECIMAL(10,6) NOT NULL,
  longitude DECIMAL(10,6) NOT NULL,
  license_certificate_url VARCHAR(255),
  degree_certificate_url VARCHAR(255),
  status ENUM('PENDING','APPROVED','REJECTED') DEFAULT 'PENDING',
  rejection_reason TEXT,
  submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);


CREATE TABLE IF NOT EXISTS reviews (
  review_id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  patient_id INT NULL,
  patient_name VARCHAR(120) NOT NULL,
  rating DECIMAL(2,1) NOT NULL,
  review_text VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE IF NOT EXISTS doctor_patient_notes (
  id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  patient_id INT NOT NULL,
  problem_description TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_doctor_patient_note (doctor_id, patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE IF NOT EXISTS doctor_patient_media (
  id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  patient_id INT NOT NULL,
  file_path VARCHAR(255) NOT NULL,
  file_type VARCHAR(20) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE IF NOT EXISTS doctor_patient_exercises (
  id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  patient_id INT NOT NULL,
  exercise_name VARCHAR(200) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE IF NOT EXISTS doctor_patient_advice (
  id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  patient_id INT NOT NULL,
  advice_text TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE IF NOT EXISTS patient_treatment (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  problem_description TEXT,
  advice_notes TEXT,
  suggested_next_appointment DATETIME NULL,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  UNIQUE KEY uq_patient_treatment_pair (patient_id, doctor_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

CREATE TABLE IF NOT EXISTS patient_exercises (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  exercise_name VARCHAR(200) NOT NULL,
  completed_flag TINYINT(1) NOT NULL DEFAULT 0,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

CREATE TABLE IF NOT EXISTS exercise_master (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(150) NOT NULL,
  description TEXT,
  demo_media_url VARCHAR(255),
  exercise_type ENUM('time','reps') NOT NULL DEFAULT 'time',
  recommended_reps VARCHAR(50) NULL,
  rep_count INT NULL,
  default_duration_seconds INT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE exercise_master
ADD COLUMN IF NOT EXISTS exercise_type ENUM('time','reps') NOT NULL DEFAULT 'time',
ADD COLUMN IF NOT EXISTS recommended_reps VARCHAR(50) NULL,
ADD COLUMN IF NOT EXISTS rep_count INT NULL,
MODIFY COLUMN default_duration_seconds INT NULL;

CREATE TABLE IF NOT EXISTS patient_exercise_assignments (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  doctor_id INT NOT NULL,
  exercise_id INT NOT NULL,
  custom_duration_seconds INT NULL,
  is_active TINYINT(1) NOT NULL DEFAULT 1,
  assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (exercise_id) REFERENCES exercise_master(id)
);

CREATE TABLE IF NOT EXISTS patient_daily_exercise_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  date DATE NOT NULL,
  completed TINYINT(1) NOT NULL DEFAULT 0,
  completed_at DATETIME NULL,
  total_exercises INT NOT NULL DEFAULT 0,
  completed_exercises INT NOT NULL DEFAULT 0,
  UNIQUE KEY uq_patient_day_log (patient_id, date),
  INDEX idx_patient_date (patient_id, date),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE IF NOT EXISTS patient_daily_exercise_item_log (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  date DATE NOT NULL,
  exercise_id INT NOT NULL,
  completed TINYINT(1) NOT NULL DEFAULT 0,
  completed_at DATETIME NULL,
  UNIQUE KEY uq_patient_day_exercise (patient_id, date, exercise_id),
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (exercise_id) REFERENCES exercise_master(id)
);

CREATE TABLE IF NOT EXISTS doctor_blogs (
  id INT AUTO_INCREMENT PRIMARY KEY,
  doctor_id INT NOT NULL,
  title VARCHAR(200) NOT NULL,
  short_description VARCHAR(500) NOT NULL,
  content LONGTEXT NOT NULL,
  media_url VARCHAR(255) NULL,
  status ENUM('draft','published') NOT NULL DEFAULT 'published',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_doctor_blogs_status_time (doctor_id, status, created_at),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

ALTER TABLE doctor_blogs MODIFY content LONGTEXT NOT NULL;

CREATE TABLE IF NOT EXISTS discussion_questions (
  id INT AUTO_INCREMENT PRIMARY KEY,
  patient_id INT NOT NULL,
  question_text TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (patient_id) REFERENCES patients(patient_id)
);

CREATE TABLE IF NOT EXISTS discussion_answers (
  id INT AUTO_INCREMENT PRIMARY KEY,
  question_id INT NOT NULL,
  doctor_id INT NOT NULL,
  answer_text TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (question_id) REFERENCES discussion_questions(id),
  FOREIGN KEY (doctor_id) REFERENCES doctors(doctor_id)
);

CREATE TABLE IF NOT EXISTS user_reports (
  id INT AUTO_INCREMENT PRIMARY KEY,
  reporter_user_id INT NOT NULL,
  reporter_role ENUM('DOCTOR','PATIENT') NOT NULL,
  reporter_doctor_id INT NULL,
  reporter_patient_id INT NULL,
  target_user_id INT NOT NULL,
  target_role ENUM('DOCTOR','PATIENT') NOT NULL,
  target_doctor_id INT NULL,
  target_patient_id INT NULL,
  reason_category VARCHAR(100) NOT NULL,
  description TEXT NOT NULL,
  status ENUM('SUBMITTED','UNDER_REVIEW','ACTION_TAKEN','CLOSED') NOT NULL DEFAULT 'SUBMITTED',
  admin_note TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  resolved_at DATETIME NULL,
  INDEX idx_user_reports_reporter (reporter_user_id, created_at),
  INDEX idx_user_reports_target_doctor (target_doctor_id, created_at),
  INDEX idx_user_reports_target_patient (target_patient_id, created_at),
  INDEX idx_user_reports_status (status, created_at),
  FOREIGN KEY (reporter_user_id) REFERENCES users(id),
  FOREIGN KEY (target_user_id) REFERENCES users(id),
  FOREIGN KEY (reporter_doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (reporter_patient_id) REFERENCES patients(patient_id),
  FOREIGN KEY (target_doctor_id) REFERENCES doctors(doctor_id),
  FOREIGN KEY (target_patient_id) REFERENCES patients(patient_id)
);

INSERT INTO exercise_master (name, description, demo_media_url, default_duration_seconds)
SELECT e.exercise_name, MAX(e.notes), NULL, 60
FROM exercises e
GROUP BY e.exercise_name
HAVING NOT EXISTS (
  SELECT 1
  FROM exercise_master em
  WHERE LOWER(em.name) = LOWER(e.exercise_name)
);

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Ankle Pumps',
       'Lie on your back and gently move your foot up and down at the ankle joint to improve circulation and ankle mobility.',
       NULL, 'reps', '15 x 3', 15, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Ankle Pumps'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Heel Raises',
       'Stand straight and slowly raise your heels off the ground, then lower them back down to strengthen calf muscles.',
       NULL, 'reps', '10 x 3', 10, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Heel Raises'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Bridging',
       'Lie on your back with knees bent. Lift hips upward while keeping shoulders on the floor.',
       NULL, 'reps', '12 x 3', 12, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Bridging'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Pelvic Tilt',
       'Lie on your back and flatten your lower back against the floor by tightening abdominal muscles.',
       NULL, 'reps', '10 x 3', 10, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Pelvic Tilt'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Plank',
       'Hold your body in a straight line supported by forearms and toes to strengthen core muscles.',
       NULL, 'time', NULL, NULL, 60
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Plank'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Side Plank',
       'Lie on one side and lift your body supported by one forearm to strengthen oblique muscles.',
       NULL, 'time', NULL, NULL, 30
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Side Plank'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Hamstring Stretch',
       'Stretch the back of the thigh by extending one leg and reaching toward toes.',
       NULL, 'time', NULL, NULL, 30
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Hamstring Stretch'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Quadriceps Stretch',
       'Stand and pull one foot toward your buttocks to stretch the front thigh muscles.',
       NULL, 'time', NULL, NULL, 30
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Quadriceps Stretch'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Wall Sit',
       'Lean against a wall and slide down into sitting position while keeping knees at 90 degrees.',
       NULL, 'time', NULL, NULL, 45
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Wall Sit'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Shoulder Rotation',
       'Rotate shoulders in circular motion forward and backward to improve mobility.',
       NULL, 'reps', '15 x 3', 15, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Shoulder Rotation'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Neck Stretch',
       'Tilt head gently to each side to stretch neck muscles.',
       NULL, 'time', NULL, NULL, 20
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Neck Stretch'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Cat-Camel Stretch',
       'On hands and knees, alternate between arching and rounding your back.',
       NULL, 'reps', '10 x 2', 10, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Cat-Camel Stretch'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Knee to Chest',
       'Pull one knee toward chest while lying on back to stretch lower back.',
       NULL, 'time', NULL, NULL, 30
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Knee to Chest'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Heel Slide',
       'Slide heel toward buttocks while lying on back to improve knee flexibility.',
       NULL, 'reps', '15 x 2', 15, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Heel Slide'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Straight Leg Raise',
       'Lift one straight leg while lying down to strengthen quadriceps.',
       NULL, 'reps', '12 x 3', 12, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Straight Leg Raise'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Clamshell Exercise',
       'Lie on side with knees bent and lift top knee while keeping feet together.',
       NULL, 'reps', '15 x 3', 15, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Clamshell Exercise'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Hip Abduction',
       'Lift leg sideways while lying down to strengthen hip muscles.',
       NULL, 'reps', '15 x 3', 15, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Hip Abduction'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Calf Stretch',
       'Lean forward against a wall to stretch calf muscles.',
       NULL, 'time', NULL, NULL, 30
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Calf Stretch'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Towel Grip Exercise',
       'Use toes to grip and release a towel placed on the floor.',
       NULL, 'reps', '20 x 2', 20, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Towel Grip Exercise'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Finger Flexion Exercise',
       'Make a fist and open fingers repeatedly to improve hand mobility.',
       NULL, 'reps', '15 x 2', 15, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Finger Flexion Exercise'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Scapular Retraction',
       'Squeeze shoulder blades together and hold briefly.',
       NULL, 'reps', '12 x 3', 12, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Scapular Retraction'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Marching in Place',
       'Lift knees alternately while standing to improve balance.',
       NULL, 'time', NULL, NULL, 60
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Marching in Place'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Step-Ups',
       'Step up and down on a platform to strengthen lower limbs.',
       NULL, 'reps', '10 x 3', 10, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Step-Ups'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Glute Bridge Hold',
       'Hold raised hip position while lying down to strengthen glutes.',
       NULL, 'time', NULL, NULL, 45
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Glute Bridge Hold'));

INSERT INTO exercise_master (name, description, demo_media_url, exercise_type, recommended_reps, rep_count, default_duration_seconds)
SELECT 'Dead Bug Exercise',
       'Lie on back and extend opposite arm and leg while keeping core tight.',
       NULL, 'reps', '10 x 3', 10, NULL
WHERE NOT EXISTS (SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Dead Bug Exercise'));
