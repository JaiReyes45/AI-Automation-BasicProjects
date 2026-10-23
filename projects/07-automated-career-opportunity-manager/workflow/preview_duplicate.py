"""Exercise duplicate handling in a disposable synthetic database."""
import json
from pathlib import Path
from tempfile import TemporaryDirectory

from workflow.service import Store


def main():
    fixture = Path(__file__).resolve().parents[1] / 'fixtures' / 'application-submitted.json'
    message = json.loads(fixture.read_text(encoding='utf-8'))
    with TemporaryDirectory(prefix='careerflow-duplicate-') as directory:
        store = Store(Path(directory) / 'test.sqlite3')
        first = store.ingest(message)
        # Reopen the store to prove deduplication is persisted, not just in memory.
        second = Store(store.path).ingest(message)
        with store.connect() as db:
            counts = {
                table: db.execute(f'SELECT COUNT(*) FROM {table}').fetchone()[0]
                for table in ('applications', 'events', 'messages', 'outbox')
            }
        output = {
            'first_duplicate': first['duplicate'],
            'second_duplicate': second['duplicate'],
            'same_application': first['application_id'] == second['application_id'],
            **counts,
            'gmail_connected': False,
        }
        assert first['duplicate'] is False
        assert second['duplicate'] is True
        assert output['same_application']
        assert all(count == 1 for count in counts.values()), output
    print(json.dumps(output, indent=2))
    print('PASS: repeated email did not create extra records. Temporary database removed.')


if __name__ == '__main__':
    main()
