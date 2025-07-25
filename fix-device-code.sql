-- Fix device code to match actual watch hash
-- Watch is sending 7824041, but database has 7824101

UPDATE devices 
SET seven_digit_code = '7824041'
WHERE seven_digit_code = '7824101';