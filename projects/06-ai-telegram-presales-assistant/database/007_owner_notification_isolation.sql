BEGIN;
-- The operator may test using the same account that receives owner notices.
-- Retain the review ticket, but do not mix internal notes into that chat.
DO $$
DECLARE definition text;
BEGIN
  SELECT pg_get_functiondef('presales.commit_decision(bigint,uuid,jsonb)'::regprocedure) INTO definition;
  IF position('owner_chat IS NOT NULL AND owner_chat <>' IN definition)=0 THEN
    IF position('IF owner_chat IS NOT NULL THEN' IN definition)=0 THEN
      RAISE EXCEPTION 'Unexpected commit_decision definition; review notification routing';
    END IF;
    definition:=replace(definition,'IF owner_chat IS NOT NULL THEN',
      'IF owner_chat IS NOT NULL AND owner_chat <> (j.envelope->>''chat_id'')::bigint THEN');
    EXECUTE definition;
  END IF;
END $$;
INSERT INTO presales.schema_migrations(version,description)
VALUES('007','Keep internal owner notifications out of the originating customer chat')
ON CONFLICT(version) DO NOTHING;
COMMIT;
