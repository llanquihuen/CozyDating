import sys
import os

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
sys.path.append(os.path.dirname(__file__))

from sync_new_furniture import sync_new_furniture

if __name__ == "__main__":
    sync_new_furniture()
