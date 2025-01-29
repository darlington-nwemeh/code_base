/*
 Function creation by Darlington C. Nwemeh Version 1.2

    This function formats a phone number for local as well as international numbers.
    While utilizing this function, the input phone number can be in various formats, including: 
    - 10-digit local numbers (e.g., 1234567890), 11-digit numbers starting with '1' (e.g., +12345678900),
    and international numbers with country codes (e.g., +1234567899000).

Copuright (c) 2025 Darlington C. Nwemeh
All rights reserved.

*/
CREATE OR REPLACE FUNCTION format_phone_number(phone_number TEXT)
RETURNS TEXT AS $$
DECLARE
-- initialize variables to hold cleaned number, country code, local number, and formatted number
    cleaned_number TEXT;
    country_code TEXT;
    local_number TEXT;
    formatted_number TEXT;
BEGIN
    -- Handle NULL input
    IF phone_number IS NULL THEN
        RETURN NULL;
    END IF;

    -- Remove all non-numeric characters except the '+' at the beginning
    cleaned_number := regexp_replace(phone_number, '[^0-9+]', '', 'g');

    -- Check if the number starts with a '+' (international format)
    IF left(cleaned_number, 1) = '+' THEN
        -- Extract the country code (up to 3 digits)
        country_code := regexp_replace(cleaned_number, '\+([0-9]{1,3}).*', '\1');
        -- Extract the remaining local number
        local_number := regexp_replace(cleaned_number, '\+[0-9]{1,3}(.*)', '\1');
    ELSE
        -- No '+' prefix; treat the first digit as a country code if 11 digits and starts with 1
        IF length(cleaned_number) = 11 AND left(cleaned_number, 1) = '1' THEN
            country_code := '1';
            local_number := substr(cleaned_number, 2);
        ELSE
            -- Otherwise, treat it as a local number
            country_code := NULL;
            local_number := cleaned_number;
        END IF;
    END IF;

    -- Ensure the local number has at least 10 digits
    IF length(local_number) < 10 THEN
        RAISE EXCEPTION 'Invalid phone number: local part must have at least 10 digits';
    END IF;

    -- Format the local number based on length
    IF length(local_number) = 10 THEN
        -- Format as (XXX) XXX-XXXX
        formatted_number := '(' || substr(local_number, 1, 3) || ') ' ||
                            substr(local_number, 4, 3) || '-' ||
                            substr(local_number, 7, 4);
    ELSIF length(local_number) > 10 THEN
        -- Dynamically group digits for international numbers
        formatted_number := substr(local_number, 1, 3) || ' ' || -- I am here!
                            substr(local_number, 4, 3) || ' ' ||
                            substr(local_number, 7, 3) || ' ' ||
                            substr(local_number, 10);
    ELSE
        -- For shorter cases, treat as-is (unlikely to occur)
        formatted_number := local_number;
    END IF;

    -- Append the country code if it exists
    IF country_code IS NOT NULL THEN
        formatted_number := '+' || country_code || ' ' || formatted_number;
    END IF;

    RETURN formatted_number;
END;
$$ LANGUAGE plpgsql;
