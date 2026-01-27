DO
$$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = 'vmemo_test') THEN
    CREATE DATABASE vmemo_test;
  END IF;
END
$$;
