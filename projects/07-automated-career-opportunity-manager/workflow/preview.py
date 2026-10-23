"""Inspect a synthetic email without writing records or contacting Gmail."""
import argparse
import json
from pathlib import Path

from workflow.engine import classify, decide


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('fixture', type=Path, help='Path to a synthetic email JSON file')
    args = parser.parse_args()
    try:
        message = json.loads(args.fixture.read_text(encoding='utf-8'))
        if not isinstance(message, dict):
            raise ValueError('The fixture must be a JSON object')
        classification = classify(message)
        _, action = decide(message, classification, [])
    except (OSError, ValueError, TypeError) as error:
        parser.exit(1, f'Cannot preview email: {error}\n')
    print(json.dumps({
        'mode': 'preview_only',
        'stage': classification['stage'],
        'role': classification['normalized_role'],
        'company': classification['company'],
        'reference': classification['reference'],
        'evidence': classification['evidence'],
        'proposed_action': action,
        'records_written': 0,
        'gmail_connected': False,
    }, indent=2))


if __name__ == '__main__':
    main()
