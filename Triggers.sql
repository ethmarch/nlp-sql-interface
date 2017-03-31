USE scheduling;

# Checks if the given professor id exists in the professor table
DROP PROCEDURE IF EXISTS prof_exists;

DELIMITER //

CREATE PROCEDURE prof_exists
(
id	INT(11)
)
BEGIN
	DECLARE	prof_exists	INT;
    
	SELECT COUNT(*)
    FROM professor
    WHERE prof_id = id;
        
	IF prof_exists = 0
	THEN
		SIGNAL SQLSTATE '45000'
			SET MESSAGE_TEXT = 'Cannot add or update row: Professor does not exist';
	END IF;
END//

DELIMITER ;

# Ensures a professor exists before assigned to a course
DROP TRIGGER IF EXISTS prof_exists_before_added_to_course;

DELIMITER //

CREATE TRIGGER prof_exists_before_added_to_course
	BEFORE INSERT ON course
    FOR EACH ROW
    BEGIN
		CALL prof_exists(NEW.prof_id);
	END//

DELIMITER ;

# Ensures a given professor can teach a class before assigned to a course
DROP TRIGGER IF EXISTS prof_can_teach_before_added_to_course;

DELIMITER //

CREATE TRIGGER prof_can_teach_before_added_to_course
	BEFORE INSERT ON course
    FOR EACH ROW
    BEGIN
		DECLARE	prof_teaches_class	INT;
        
        SELECT COUNT(*)
        INTO prof_teaches_class
        FROM prof_subject
        WHERE prof_id = NEW.prof_id
			AND course_subject = NEW.course_subject
            AND course_number = NEW.course_num;
		
        IF prof_teaches_class = 0
        THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Cannot add or update row: Professor does not teach class';
		END IF;
	END //

DELIMITER ;

# Adds a registration to prof_reg after assigned to a course
DROP TRIGGER IF EXISTS prof_in_reg_after_added_to_course;

DELIMITER //

CREATE TRIGGER prof_in_reg_after_added_to_course
	AFTER INSERT ON course
    FOR EACH ROW
    BEGIN
		DECLARE max_seq	INT;
        
        SELECT MAX(teaching_seq)
        INTO max_seq
        FROM prof_reg
        WHERE prof_id = NEW.prof_id;
        
        INSERT INTO prof_reg
        VALUES (NEW.prof_id, max_seq + 1, NEW.crn);
	END//

DELIMITER ;

# Ensures a professor exists before declaring what s/he can teach
DROP TRIGGER IF EXISTS prof_exists_before_can_teach;

DELIMITER //

CREATE TRIGGER prof_exists_before_can_teach
	BEFORE INSERT ON prof_subject
    FOR EACH ROW
    BEGIN
		CALL prof_exists(NEW.prof_id);
	END//

DELIMITER ;

# Checks that a classroom exists before it is assigned to a course
DROP TRIGGER IF EXISTS classroom_exists_before_added_to_course;

DELIMITER //

CREATE TRIGGER classroom_exists_before_added_to_course
	BEFORE INSERT ON course
    FOR EACH ROW
    BEGIN
		DECLARE	room_count	INT;
        
        SELECT COUNT(*)
        INTO room_count
        FROM classroom
        WHERE room_idx = NEW.room_idx;
        
        IF room_count = 0
        THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Cannot add or update row: Classroom does not exist';
		END IF;
	END//

DELIMITER ;

# Checks that a classroom exists before it is assigned to a course
DROP TRIGGER IF EXISTS classroom_exists_before_added_to_course;

DELIMITER //

CREATE TRIGGER classroom_exists_before_added_to_course
	BEFORE INSERT ON course
    FOR EACH ROW
    BEGIN
		DECLARE	room_count	INT;
        
        SELECT COUNT(*)
        INTO room_count
        FROM classroom
        WHERE room_idx = NEW.room_idx;
        
        IF room_count = 0
        THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Cannot add or update row: Classroom does not exist';
		END IF;
	END//

DELIMITER ;

# Checks that a course capacity does not exceed its room's capacity
DROP TRIGGER IF EXISTS course_capacity_less_than_room_capacity;

DELIMITER //

CREATE TRIGGER course_capacity_less_than_room_capacity
	BEFORE INSERT ON course
    FOR EACH ROW
    BEGIN
		DECLARE	room_cap	INT;
        
        SELECT capacity
        INTO room_cap
        FROM classroom
        WHERE room_idx = NEW.room_idx;
        
        IF room_cap < NEW.capacity
        THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Cannot add or update row: Course capacity exceeds room capacity';
		END IF;
	END//

DELIMITER ;

# Checks that a course registration does not exceed its capacity
DROP TRIGGER IF EXISTS course_reg_less_than_capacity;

DELIMITER //

CREATE TRIGGER course_reg_less_than_capacity
	BEFORE INSERT ON course
    FOR EACH ROW
    BEGIN
		DECLARE	course_reg	INT;
        
        # Students cannot register for the same course twice, so this will always
        # produce the number of unique students that registered for the course
        SELECT COUNT(*)
        INTO course_reg
        FROM student_reg
        WHERE reg_crn = NEW.crn;
        
        IF course_reg > NEW.capacity
        THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Cannot add or update row: Course full';
		END IF;
	END//

DELIMITER ;

# Ensures student cannot register for same course twice
DROP TRIGGER IF EXISTS student_already_registered_not_registered_again;

DELIMITER //

CREATE TRIGGER student_already_registered_not_registered_again
	BEFORE INSERT ON student_reg
    FOR EACH ROW
    BEGIN
		DECLARE	student_registered	BOOLEAN;
        
        SELECT IF(COUNT(*) = 0, 0, 1)
        INTO student_registered
        FROM student_reg
        WHERE student_id = NEW.student_id
			AND reg_crn = NEW.reg_crn;
        
        IF student_registered
        THEN
			SIGNAL SQLSTATE '45000'
				SET MESSAGE_TEXT = 'Cannot add or update row: Student already registered for course';
		END IF;
	END//

DELIMITER ;

# Checks if student has prerequisites for class before registered for course
DROP TRIGGER IF EXISTS check_prerequisites;

DELIMITER //
-- 
-- CREATE TRIGGER check_prerequisites
-- 	BEFORE INSERT ON student_reg
--     FOR EACH ROW
--     BEGIN
-- 		