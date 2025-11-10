-- ==============================================================
-- LOST & FOUND MANAGEMENT SYSTEM (MySQL Compatible Project)
-- ==============================================================

DROP TABLE IF EXISTS LostItems;
DROP TABLE IF EXISTS FoundItems;
DROP TABLE IF EXISTS MatchResults;
DROP PROCEDURE IF EXISTS GenerateMatches;

-- --------------------------------------------------------------
-- TABLE: Lost Items
-- --------------------------------------------------------------
CREATE TABLE LostItems (
    lost_id INT AUTO_INCREMENT PRIMARY KEY,
    item_name VARCHAR(100),
    category VARCHAR(50),
    lost_location VARCHAR(100),
    lost_date DATE,
    owner_name VARCHAR(100),
    contact VARCHAR(50),
    description TEXT
);

-- --------------------------------------------------------------
-- TABLE: Found Items
-- --------------------------------------------------------------
CREATE TABLE FoundItems (
    found_id INT AUTO_INCREMENT PRIMARY KEY,
    item_name VARCHAR(100),
    category VARCHAR(50),
    found_location VARCHAR(100),
    found_date DATE,
    finder_name VARCHAR(100),
    contact VARCHAR(50),
    description TEXT
);

-- --------------------------------------------------------------
-- TABLE: Match Results
-- --------------------------------------------------------------
CREATE TABLE MatchResults (
    match_id INT AUTO_INCREMENT PRIMARY KEY,
    lost_id INT,
    found_id INT,
    match_score INT,
    status VARCHAR(40),
    match_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- --------------------------------------------------------------
-- SAMPLE DATA: Lost Items
-- --------------------------------------------------------------
INSERT INTO LostItems (item_name, category, lost_location, lost_date, owner_name, contact, description)
VALUES
('Wallet', 'Accessories', 'Library', '2025-11-01', 'Rohit Kumar', '9876543210', 'Brown leather wallet'),
('Phone', 'Electronics', 'Cafeteria', '2025-10-28', 'Aisha Thapa', '9841234567', 'Samsung phone cracked screen'),
('Laptop Bag', 'Electronics', 'Classroom A2', '2025-11-04', 'Suresh Patel', '9800001111', 'Grey laptop bag');

-- --------------------------------------------------------------
-- SAMPLE DATA: Found Items
-- --------------------------------------------------------------
INSERT INTO FoundItems (item_name, category, found_location, found_date, finder_name, contact, description)
VALUES
('Wallet', 'Accessories', 'Library', '2025-11-02', 'Meena Sharma', '9898989898', 'Found inside library'),
('Mobile Phone', 'Electronics', 'Cafeteria', '2025-10-29', 'John Doe', '9009009009', 'Black phone cracked screen'),
('Bag', 'Electronics', 'Classroom A2', '2025-11-05', 'Ankit Rawat', '9777777777', 'Grey laptop bag found');

-- --------------------------------------------------------------
-- STORED PROCEDURE: MATCH LOST & FOUND
-- --------------------------------------------------------------
DELIMITER $$

CREATE PROCEDURE GenerateMatches()
BEGIN
    DECLARE finished INT DEFAULT 0;
    DECLARE l_id INT;
    DECLARE l_name VARCHAR(100);
    DECLARE l_cat VARCHAR(50);
    DECLARE l_loc VARCHAR(100);
    DECLARE l_date DATE;

    DECLARE f_id INT;
    DECLARE temp_score INT;

    DECLARE cur CURSOR FOR
        SELECT lost_id, item_name, category, lost_location, lost_date FROM LostItems;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = 1;

    -- Clear old results
    DELETE FROM MatchResults;

    OPEN cur;

    itemLoop: LOOP
        FETCH cur INTO l_id, l_name, l_cat, l_loc, l_date;
        IF finished = 1 THEN
            LEAVE itemLoop;
        END IF;

        -- Try to find a FOUND record with similar category, location, and date
        SET f_id = NULL;

        SELECT found_id INTO f_id
        FROM FoundItems
        WHERE category = l_cat
          AND found_location = l_loc
          AND ABS(DATEDIFF(found_date, l_date)) <= 3
        LIMIT 1;

        -- If not found, try weaker matching
        IF f_id IS NULL THEN
            SELECT found_id INTO f_id
            FROM FoundItems
            WHERE category = l_cat
              AND (found_location LIKE CONCAT('%', SUBSTRING(l_loc,1,3), '%'))
            LIMIT 1;
        END IF;

        -- If a match is found, calculate score
        IF f_id IS NOT NULL THEN
            SET temp_score = 50;

            -- name similarity check
            IF (SELECT item_name FROM FoundItems WHERE found_id=f_id) LIKE CONCAT('%', l_name, '%')
               OR l_name LIKE CONCAT('%', (SELECT item_name FROM FoundItems WHERE found_id=f_id), '%')
            THEN
                SET temp_score = temp_score + 20;
            END IF;

            -- location exact
            IF l_loc = (SELECT found_location FROM FoundItems WHERE found_id = f_id) THEN
                SET temp_score = temp_score + 30;
            END IF;

            INSERT INTO MatchResults(lost_id, found_id, match_score, status)
            VALUES (
                l_id,
                f_id,
                temp_score,
                CASE
                    WHEN temp_score >= 80 THEN 'Strong Match'
                    WHEN temp_score >= 60 THEN 'Moderate Match'
                    ELSE 'Weak Match'
                END
            );
        END IF;
    END LOOP;

    CLOSE cur;
END$$

DELIMITER ;

-- --------------------------------------------------------------
-- RUN THE PROCEDURE
-- --------------------------------------------------------------
CALL GenerateMatches();

-- --------------------------------------------------------------
-- VIEW FOR CLEAN OUTPUT
-- --------------------------------------------------------------
CREATE OR REPLACE VIEW MatchReport AS
SELECT 
    M.match_id,
    L.item_name AS LostItem,
    F.item_name AS FoundItem,
    L.lost_location AS LostLocation,
    F.found_location AS FoundLocation,
    L.lost_date AS LostDate,
    F.found_date AS FoundDate,
    M.match_score AS Score,
    M.status AS MatchStatus
FROM MatchResults M
JOIN LostItems L ON M.lost_id = L.lost_id
JOIN FoundItems F ON M.found_id = F.found_id
ORDER BY M.match_score DESC;

-- --------------------------------------------------------------
-- DISPLAY REPORT
-- --------------------------------------------------------------
SELECT * FROM MatchReport;