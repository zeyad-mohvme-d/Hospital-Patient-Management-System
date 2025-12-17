-- 1.3) Table Creation
--------------------------------------------------
Show user;

CREATE TABLE Patients (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(100),
  date_of_birth DATE,
  status VARCHAR2(20),
  total_bill NUMBER(10,2),
  room_id NUMBER
);

CREATE TABLE Doctors (
  id NUMBER PRIMARY KEY,
  name VARCHAR2(100),
  specialty VARCHAR2(100),
  available_hours NUMBER
);

CREATE TABLE Appointments (
  id NUMBER PRIMARY KEY,
  patient_id NUMBER REFERENCES Patients(id),
  doctor_id NUMBER REFERENCES Doctors(id),
  appointment_date DATE,
  status VARCHAR2(20)
);

CREATE TABLE Treatments (
  id NUMBER PRIMARY KEY,
  patient_id NUMBER REFERENCES Patients(id),
  doctor_id NUMBER REFERENCES Doctors(id),
  treatment_description VARCHAR2(200),
  cost NUMBER(10,2)
);

CREATE TABLE Rooms (
  id NUMBER PRIMARY KEY,
  room_type VARCHAR2(50),
  capacity NUMBER,
  availability NUMBER
);

CREATE TABLE Warnings (
  id NUMBER PRIMARY KEY,
  patient_id NUMBER REFERENCES Patients(id),
  warning_reason VARCHAR2(200),
  warning_date DATE
);

CREATE TABLE AuditTrail (
  id NUMBER PRIMARY KEY,
  table_name VARCHAR2(50),
  operation VARCHAR2(20),
  old_data CLOB,
  new_data CLOB,
  action_date TIMESTAMP DEFAULT SYSTIMESTAMP
);

-- 1.5) SEQUENCE Creation
--------------------------------------------------
CREATE SEQUENCE seq_patients     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_doctors      START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_appointments START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_treatments   START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_rooms        START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_warnings     START WITH 1 INCREMENT BY 1;
CREATE SEQUENCE seq_audit        START WITH 1 INCREMENT BY 1;

-- Ro7 ll XEPDB1

--------------------------------------------------
-- Error 0.3
--------------------------------------------------
SELECT table_schema, table_name, privilege
FROM all_tab_privs
WHERE grantee = 'HOSP_USER2';

-- kda el error athl 
-- Arg3 ll User2
--------------------------------------------------


---------------------------------------------------------------
-- TASK (2)
---------------------------------------------------------------

-- 2.0) Patient Admission Validation Trigger
--------------------------------------------------
CREATE OR REPLACE TRIGGER trg_patient_admission
BEFORE INSERT ON Patients
FOR EACH ROW
DECLARE
  v_available NUMBER;
BEGIN
  SELECT availability INTO v_available
  FROM Rooms
  WHERE id = :NEW.room_id
  FOR UPDATE;

  IF v_available <= 0 THEN
    RAISE_APPLICATION_ERROR(-20001,'No available rooms.');
  END IF;

  UPDATE Rooms SET availability = availability - 1
  WHERE id = :NEW.room_id;

  INSERT INTO AuditTrail VALUES
  (seq_audit.NEXTVAL,'Patients','INSERT',NULL,
   'Patient admitted',SYSTIMESTAMP);
END;


---------------------------------------------------------------
-- TASK (3)
---------------------------------------------------------------

-- 3.0) Appointment Scheduling Procedure
--------------------------------------------------
CREATE OR REPLACE PROCEDURE Schedule_Appointment(
  p_patient NUMBER,
  p_doctor NUMBER,
  p_date DATE
) AS
  v_hours NUMBER;
BEGIN
  SELECT available_hours INTO v_hours
  FROM Doctors WHERE id = p_doctor;

  IF v_hours <= 0 THEN
    RAISE_APPLICATION_ERROR(-20002,'Doctor not available');
  END IF;

  INSERT INTO Appointments
  VALUES (seq_appointments.NEXTVAL,p_patient,p_doctor,p_date,'Scheduled');

  UPDATE Doctors SET available_hours = available_hours - 1
  WHERE id = p_doctor;

  COMMIT;
END;
/


---------------------------------------------------------------
-- TASK (4)
---------------------------------------------------------------

-- 4.0) Treatment Cost Calculation Function
--------------------------------------------------
CREATE OR REPLACE FUNCTION Calc_Total_Treatment(p_patient NUMBER)
RETURN NUMBER AS
  v_total NUMBER;
BEGIN
  SELECT NVL(SUM(cost),0)
  INTO v_total FROM Treatments
  WHERE patient_id = p_patient;

  UPDATE Patients SET total_bill = v_total
  WHERE id = p_patient;

  COMMIT;
  RETURN v_total;
END;
/


---------------------------------------------------------------
-- TASK (5)
---------------------------------------------------------------

-- 5.0) Room Assignment Trigger
--------------------------------------------------
CREATE OR REPLACE TRIGGER trg_room_assign
BEFORE INSERT ON Patients
FOR EACH ROW
BEGIN
  INSERT INTO AuditTrail VALUES
  (seq_audit.NEXTVAL,'Rooms','ASSIGN',NULL,'Room assigned',SYSTIMESTAMP);
END;
/


---------------------------------------------------------------
-- TASK (6)
---------------------------------------------------------------

-- 6.0) Discharge Processing
--------------------------------------------------
CREATE OR REPLACE PROCEDURE Discharge_Patient(p_id NUMBER) AS
  v_room NUMBER;
BEGIN
  SELECT room_id INTO v_room FROM Patients WHERE id=p_id;

  UPDATE Patients SET status='Discharged' WHERE id=p_id;
  UPDATE Rooms SET availability = availability + 1 WHERE id=v_room;

  INSERT INTO AuditTrail VALUES
  (seq_audit.NEXTVAL,'Patients','DISCHARGE',NULL,'Patient discharged',SYSTIMESTAMP);

  COMMIT;
END;
/


---------------------------------------------------------------
-- TASK (7)
---------------------------------------------------------------

-- 7.0) Hospital Performance Report (Cursor)
--------------------------------------------------
CREATE OR REPLACE PROCEDURE Hospital_Report AS
  CURSOR c IS
    SELECT specialty, COUNT(*) cnt FROM Doctors GROUP BY specialty;
BEGIN
  DBMS_OUTPUT.PUT_LINE('Hospital Performance Report');
  FOR r IN c LOOP
    DBMS_OUTPUT.PUT_LINE(r.specialty || ' -> ' || r.cnt);
  END LOOP;
END;
/


---------------------------------------------------------------
-- TASK (8)
---------------------------------------------------------------

-- 8.0) Multi-Appointment Cancellation (Transaction Safe)
--------------------------------------------------
CREATE OR REPLACE PROCEDURE Cancel_Appointments(p_patient NUMBER) AS
BEGIN
  UPDATE Appointments SET status='Cancelled'
  WHERE patient_id=p_patient;

  COMMIT;
EXCEPTION
  WHEN OTHERS THEN
    ROLLBACK;
    RAISE;
END;
/


---------------------------------------------------------------
-- TASK (9)
---------------------------------------------------------------

-- 9.0) Patient Warnings
--------------------------------------------------
CREATE OR REPLACE PROCEDURE Issue_Warning(p_patient NUMBER,p_reason VARCHAR2) AS
  v_count NUMBER;
BEGIN
  INSERT INTO Warnings
  VALUES (seq_warnings.NEXTVAL,p_patient,p_reason,SYSDATE);

  SELECT COUNT(*) INTO v_count FROM Warnings WHERE patient_id=p_patient;

  IF v_count >= 3 THEN
    UPDATE Patients SET status='Flagged' WHERE id=p_patient;
  END IF;

  COMMIT;
END;
/


---------------------------------------------------------------
-- TASK (10)
---------------------------------------------------------------

-- 10.0) Advanced Data Functions
--------------------------------------------------
CREATE OR REPLACE FUNCTION get_doctor_patient_count(p_doc NUMBER)
RETURN NUMBER AS
  v_cnt NUMBER;
BEGIN
  SELECT COUNT(DISTINCT patient_id)
  INTO v_cnt FROM Treatments WHERE doctor_id=p_doc;
  RETURN v_cnt;
END;
/

CREATE OR REPLACE PROCEDURE update_patient_status_by_bill(p_limit NUMBER) AS
BEGIN
  UPDATE Patients SET status='High-Value'
  WHERE total_bill > p_limit;
  COMMIT;
END;
/


--------------------------------------------------
-- Testing 
--------------------------------------------------
SET SERVEROUTPUT ON
SHOW USER;

SELECT * FROM Rooms;
INSERT INTO Patients
VALUES (seq_patients.NEXTVAL, 'Test Patient', DATE '2000-01-01',
        'Admitted', 0, 1);
        
SELECT id FROM Patients ORDER BY id;

SELECT seq_patients.CURRVAL FROM dual;

SELECT MAX(id) FROM Patients;

DROP SEQUENCE seq_patients;
CREATE SEQUENCE seq_patients
START WITH 3
INCREMENT BY 1;

INSERT INTO Patients
VALUES (
  seq_patients.NEXTVAL,
  'Test Patient',
  DATE '2000-01-01',
  'Admitted',
  0,
  1
);

COMMIT;

SELECT id, name FROM Patients ORDER BY id;

SELECT * FROM Rooms WHERE id = 1;

SELECT * FROM AuditTrail WHERE table_name = 'Patients';

INSERT INTO Patients
VALUES (
    seq_patients.NEXTVAL, 
    'Fail Patient',
    SYSDATE,
    'Admitted', 
    0, 
    1
);

UPDATE Rooms
SET availability = capacity
WHERE id = 1;

COMMIT;

SELECT id, room_type, capacity, availability
FROM Rooms
WHERE id = 1;

-- اشتغلللللللللللللللللللللللللللللللللللللللللللللللللللل

---------------------------------------------------------------
-- TASK (11): Blocker–Waiting Situation
---------------------------------------------------------------

-- 11.0) Blocker
--------------------------------------------------
SHOW USER;

UPDATE Rooms
SET availability = availability - 1
WHERE id = 1;

-- Ro7 ll User2


-- 12.1) Release the lock
--------------------------------------------------
COMMIT;

