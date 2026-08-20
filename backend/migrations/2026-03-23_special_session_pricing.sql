USE physiotrack;

ALTER TABLE appointments
  ADD COLUMN is_special_session TINYINT(1) NOT NULL DEFAULT 0;

ALTER TABLE appointments
  ADD COLUMN special_fee_amount DECIMAL(10,2) NULL;

ALTER TABLE appointments
  ADD COLUMN special_fee_reason VARCHAR(255) NULL;
