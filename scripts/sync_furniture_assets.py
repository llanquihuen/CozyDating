import sys
import os

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.append(os.path.dirname(__file__))

from sync_new_furniture import main

if __name__ == "__main__":
    # Acepta --dry-run, --list-orphans y --furniture-dir (ver sync_new_furniture.py).
    main()
