USE physiotrack;

INSERT INTO doctors
  (name, age, qualification, years_of_experience, clinic_name, rating, profile_image_url, latitude, longitude)
VALUES
  ('Dr. Revathi', 34, 'MPT', 8, 'Maxio Physio Clinic', 4.7, 'https://via.placeholder.com/150', 11.0168, 76.9558),
  ('Dr. Ram Kumar', 38, 'BPT', 11, 'RK Physiotherapy Center', 4.5, 'https://via.placeholder.com/150', 11.0200, 76.9700),
  ('Dr. Kalaivani', 33, 'MPT', 7, 'Kinergy Physiotherapy Center', 4.6, 'https://via.placeholder.com/150', 11.0070, 76.9600),
  ('Dr. Praveen', 36, 'BPT', 9, 'We Cure Physio Clinic', 4.3, 'https://via.placeholder.com/150', 11.0300, 76.9800),
  ('Dr. Deepa Subramaniam', 40, 'MPT', 13, 'Yuktha Physio Hub', 4.8, 'https://via.placeholder.com/150', 11.0150, 76.9900),
  ('Dr. Saravanan', 37, 'BPT', 10, 'HealWell Clinic', 4.4, 'https://via.placeholder.com/150', 11.0250, 76.9650),
  ('Dr. Aathisha', 32, 'MPT', 6, 'Duraisamy Physio Clinic', 4.2, 'https://via.placeholder.com/150', 11.0180, 76.9450),
  ('Dr. Gopala Krishnan', 41, 'BPT', 15, 'GetWell Physiotherapy Clinic', 4.1, 'https://via.placeholder.com/150', 11.0350, 76.9750),
  ('Dr. Ananya Kumar', 35, 'MPT', 9, 'Kumar Physio Clinic', 4.7, 'https://via.placeholder.com/150', 11.0120, 76.9520),
  ('Dr. Rahul Sharma', 39, 'BPT', 12, 'Sharma Rehab Center', 4.5, 'https://via.placeholder.com/150', 11.0420, 76.9900),
  ('Dr. Meera Iyer', 31, 'MPT', 5, 'Iyer Physiotherapy', 4.6, 'https://via.placeholder.com/150', 11.0260, 76.9400),
  ('Dr. Karthik Rao', 36, 'BPT', 8, 'Rehab Plus', 4.3, 'https://via.placeholder.com/150', 11.0500, 76.9800),
  ('Dr. Sneha Nair', 34, 'MPT', 7, 'Care Physio Hub', 4.8, 'https://via.placeholder.com/150', 11.0550, 76.9650),
  ('Dr. Arjun Das', 37, 'BPT', 10, 'HealWell Clinic 2', 4.4, 'https://via.placeholder.com/150', 11.0600, 76.9500),
  ('Dr. Priya Menon', 33, 'MPT', 6, 'Prime Physio', 4.2, 'https://via.placeholder.com/150', 11.0650, 76.9550),
  ('Dr. Vivek Singh', 40, 'BPT', 14, 'MotionCare', 4.1, 'https://via.placeholder.com/150', 11.0700, 76.9600),
  ('Dr. Anand Raj', 38, 'MPT', 11, 'Restore Physio', 4.6, 'https://via.placeholder.com/150', 11.0750, 76.9700),
  ('Dr. Nivedha S', 29, 'BPT', 4, 'Pulse Physio', 4.0, 'https://via.placeholder.com/150', 11.0800, 76.9750),
  ('Dr. Joseph Paul', 43, 'MPT', 16, 'Core Motion Clinic', 4.5, 'https://via.placeholder.com/150', 11.0850, 76.9800),
  ('Dr. Lakshmi Priya', 35, 'BPT', 9, 'ActiveCare Physio', 4.3, 'https://via.placeholder.com/150', 11.0900, 76.9850);

INSERT INTO patients
  (name, age, email, phone, address)
VALUES
  ('Ravi Kumar', 28, 'ravi.k@example.com', '9876543210', 'RS Puram, Coimbatore'),
  ('Ajay Saravanan', 35, 'ajay.s@example.com', '9876543211', 'Saibaba Colony, Coimbatore'),
  ('Aaravind', 42, 'aaravind@example.com', '9876543212', 'Peelamedu, Coimbatore'),
  ('Sherill', 31, 'sherill@example.com', '9876543213', 'Race Course, Coimbatore'),
  ('Meera Nair', 29, 'meera.n@example.com', '9876543214', 'Gandhipuram, Coimbatore'),
  ('Kiran Joshi', 38, 'kiran.j@example.com', '9876543215', 'Vadavalli, Coimbatore'),
  ('Aarav Patel', 33, 'aarav.p@example.com', '9876543216', 'RS Puram, Coimbatore'),
  ('Shyam', 26, 'shyam.r@example.com', '9876543217', 'Singanallur, Coimbatore'),
  ('Sneha Iyer', 30, 'sneha.i@example.com', '9876543218', 'Peelamedu, Coimbatore'),
  ('Karthik Rao', 36, 'karthik.r@example.com', '9876543219', 'Saravanampatti, Coimbatore'),
  ('Priya Menon', 32, 'priya.m@example.com', '9876543220', 'Town Hall, Coimbatore'),
  ('Vivek Singh', 41, 'vivek.s@example.com', '9876543221', 'Ukkadam, Coimbatore'),
  ('Lalitha R', 27, 'lalitha.r@example.com', '9876543222', 'Gandhipuram, Coimbatore'),
  ('Madhan K', 34, 'madhan.k@example.com', '9876543223', 'Kovilmedu, Coimbatore'),
  ('Sonia George', 29, 'sonia.g@example.com', '9876543224', 'Ramanathapuram, Coimbatore'),
  ('Arun Prakash', 37, 'arun.p@example.com', '9876543225', 'Avinashi Road, Coimbatore'),
  ('Divya V', 31, 'divya.v@example.com', '9876543226', 'Sivananda Colony, Coimbatore'),
  ('Manoj D', 40, 'manoj.d@example.com', '9876543227', 'Kuniyamuthur, Coimbatore'),
  ('Poornima S', 33, 'poornima.s@example.com', '9876543228', 'Thudiyalur, Coimbatore'),
  ('Rohit N', 28, 'rohit.n@example.com', '9876543229', 'Ganapathy, Coimbatore');

INSERT INTO appointments
  (doctor_id, patient_id, appointment_date, appointment_time, status, visit_type)
VALUES
  (1, 1, '10-02-2026', '09:00 AM', 'REQUESTED', 'CLINIC'),
  (2, 2, '10-02-2026', '11:30 AM', 'REQUESTED', 'HOME'),
  (3, 3, '11-02-2026', '04:00 PM', 'REQUESTED', 'CLINIC'),
  (4, 4, '12-02-2026', '10:30 AM', 'APPROVED', 'CLINIC'),
  (5, 5, '12-02-2026', '05:00 PM', 'APPROVED', 'HOME'),
  (6, 6, '13-02-2026', '09:15 AM', 'APPROVED', 'CLINIC'),
  (7, 7, '13-02-2026', '02:00 PM', 'COMPLETED', 'HOME'),
  (8, 8, '14-02-2026', '04:30 PM', 'COMPLETED', 'CLINIC');


INSERT INTO exercises (patient_id, doctor_id, exercise_name, status, notes) VALUES
  (1, 1, 'Ankle Pumps', 'PENDING', '2 sets, 10 reps daily'),
  (1, 1, 'Neck Stretch', 'DONE', 'Morning routine'),
  (2, 1, 'Shoulder Rotation', 'PENDING', 'Slow and controlled'),
  (3, 2, 'Hamstring Stretch', 'PENDING', 'Hold for 20 seconds'),
  (4, 2, 'Bridging', 'DONE', '3 sets, 8 reps'),
  (5, 3, 'Heel Slide', 'PENDING', 'Pain free range only');


INSERT INTO reviews (doctor_id, patient_id, patient_name, rating, review_text) VALUES
  (1, 1, 'Ravi Kumar', 4.5, 'Very helpful sessions.'),
  (2, 2, 'Ajay Saravanan', 4.0, 'Clear explanation and guidance.');
