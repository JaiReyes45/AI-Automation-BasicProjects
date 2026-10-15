"""One-time owner setup from the sole existing private test customer; no ID output."""
import subprocess
q="""DO $$ DECLARE owner_id bigint; n integer; BEGIN
SELECT count(*),min(telegram_user_id) INTO n,owner_id FROM presales.customers;
IF n<>1 OR owner_id IS NULL OR owner_id<=0 THEN RAISE EXCEPTION 'Explicit owner selection required; expected one existing private test customer'; END IF;
PERFORM presales.configure_owner_chat(owner_id);
END $$;"""
p=subprocess.run(['docker','exec','-i','project06-presales-postgres-1','psql','-U','presales','-d','presales','-v','ON_ERROR_STOP=1'],input=q,text=True,capture_output=True)
if p.returncode:raise SystemExit('Owner setup failed; inspect the schema/customer count without exposing IDs.')
print('Private owner notification destination configured; no identifiers exported.')
