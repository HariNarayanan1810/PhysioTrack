UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Ankle_pump_-_Fit_Family_Physical_Therapy_720P.mp4'
WHERE LOWER(name) = LOWER('Ankle Pumps');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Banded_Clam_Shell_Exercise_720P.mp4'
WHERE LOWER(name) = LOWER('Clamshell Exercise');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Bridge_720P.mp4'
WHERE LOWER(name) = LOWER('Bridging');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Cat_Camel_-_Spine_Mobility_Exercise_720P.mp4'
WHERE LOWER(name) = LOWER('Cat-Camel Stretch');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Dead_Bug_Level_1_720P.mp4'
WHERE LOWER(name) = LOWER('Dead Bug Exercise');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Gastroc_Stretch_720P.mp4'
WHERE LOWER(name) = LOWER('Calf Stretch');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Heel_Raises_720P.mp4'
WHERE LOWER(name) = LOWER('Heel Raises');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Marching_in_Place_720P.mp4'
WHERE LOWER(name) = LOWER('Marching in Place');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Plank_with_alternating_forward_reach_-_Fit_Family_Physical_Therapy_720P.mp4'
WHERE LOWER(name) = LOWER('Plank');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Posterior_Pelvic_Tilt_720P.mp4'
WHERE LOWER(name) = LOWER('Pelvic Tilt');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Power_Grip_with_Towel_720P.mp4'
WHERE LOWER(name) = LOWER('Towel Grip Exercise');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Scapular_Retraction_Sit_720P.mp4'
WHERE LOWER(name) = LOWER('Scapular Retraction');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Shoulder_wall_isometrics_external_rotation_-_Fit_Family_Physical_Therapy_720P.mp4'
WHERE LOWER(name) = LOWER('Shoulder Rotation');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Side_plank_with_hip_dip_-_Fit_Family_Physical_Therapy_720P.mp4'
WHERE LOWER(name) = LOWER('Side Plank');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Step_Up_720P.mp4'
WHERE LOWER(name) = LOWER('Step-Ups');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Straight_Leg_Raise_480P.mp4'
WHERE LOWER(name) = LOWER('Straight Leg Raise');

UPDATE exercise_master
SET demo_media_url = '/uploads/exercises/Wall_Sit.mp4'
WHERE LOWER(name) = LOWER('Wall Sit');

INSERT INTO exercise_master (
  name,
  description,
  demo_media_url,
  exercise_type,
  recommended_reps,
  rep_count,
  default_duration_seconds
)
SELECT
  'Hamstring Set',
  'Tighten the muscles at the back of the thigh while keeping the leg stable and controlled.',
  '/uploads/exercises/Hamstring_Set_480P.mp4',
  'reps',
  '10 x 3',
  10,
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Hamstring Set')
);

INSERT INTO exercise_master (
  name,
  description,
  demo_media_url,
  exercise_type,
  recommended_reps,
  rep_count,
  default_duration_seconds
)
SELECT
  'Hip Adduction Ball Squeeze',
  'Squeeze a ball or cushion between the knees while lying on your back to activate inner thigh muscles.',
  '/uploads/exercises/Hip_Adduction_Supine_Ball_Squeeze_720P.mp4',
  'reps',
  '12 x 3',
  12,
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Hip Adduction Ball Squeeze')
);

INSERT INTO exercise_master (
  name,
  description,
  demo_media_url,
  exercise_type,
  recommended_reps,
  rep_count,
  default_duration_seconds
)
SELECT
  'Quadratus Lumborum Stretch',
  'Reach overhead while standing and lean sideways gently to stretch the side of the lower back.',
  '/uploads/exercises/Quadratus_Lumborum_Standing_with_Overhead_Reach_720P.mp4',
  'time',
  NULL,
  NULL,
  30
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Quadratus Lumborum Stretch')
);

INSERT INTO exercise_master (
  name,
  description,
  demo_media_url,
  exercise_type,
  recommended_reps,
  rep_count,
  default_duration_seconds
)
SELECT
  'Scalene Stretch',
  'Tilt the neck gently to target the scalene muscles and improve neck flexibility.',
  '/uploads/exercises/Scalene_Stretch_720P.mp4',
  'time',
  NULL,
  NULL,
  20
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Scalene Stretch')
);

INSERT INTO exercise_master (
  name,
  description,
  demo_media_url,
  exercise_type,
  recommended_reps,
  rep_count,
  default_duration_seconds
)
SELECT
  'Single Leg Glute Bridge',
  'Lift the hips with one leg supported to strengthen the glutes and posterior chain.',
  '/uploads/exercises/Single_leg_glute_bridge_720P.mp4',
  'reps',
  '10 x 3',
  10,
  NULL
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Single Leg Glute Bridge')
);

INSERT INTO exercise_master (
  name,
  description,
  demo_media_url,
  exercise_type,
  recommended_reps,
  rep_count,
  default_duration_seconds
)
SELECT
  'Wrist Flexor and Extensor Stretch',
  'Stretch both the wrist flexors and extensors to improve hand and forearm mobility.',
  '/uploads/exercises/Wrist_Extension_Stretch_Flexor_Stretch_720P.mp4',
  'time',
  NULL,
  NULL,
  20
WHERE NOT EXISTS (
  SELECT 1 FROM exercise_master WHERE LOWER(name) = LOWER('Wrist Flexor and Extensor Stretch')
);
